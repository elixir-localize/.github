defmodule ElixirLocalize.Web.XmlRpc do
  @moduledoc """
  XML-RPC shim that lets MarsEdit (configured with either the "Micropub" or
  "Micro.blog" system type) list and fetch posts from this blog.

  The Micropub specification defines a clean JSON API for writes but has no
  standard query for listing all posts. MarsEdit consequently falls back to
  the micro.blog XML-RPC vocabulary — `microblog.getPosts`,
  `metaWeblog.getRecentPosts`, `metaWeblog.getPost`,
  `blogger.getUsersBlogs` — to populate its post-list sidebar, even when the
  blog is otherwise treated as a Micropub blog.

  This module implements just enough of that vocabulary for MarsEdit to
  function. Writes still go through `ElixirLocalize.Micropub` on the
  JSON/form-encoded path.

  Authentication is HTTP Basic. Any username is accepted; the password must
  match `LOCALIZE_BLOG_TOKEN`.
  """

  require Logger

  alias ElixirLocalize.RuntimePosts

  @type fault :: {:fault, integer(), String.t()}

  @doc """
  Handle a single XML-RPC method call.

  ### Arguments

  * `method_name` is the XML-RPC method name (e.g. `"microblog.getPosts"`).

  * `params` is the decoded parameter list from `XMLRPC.MethodCall`.

  ### Returns

  * `{:ok, value}` where `value` is the Elixir term to encode as the
    `<methodResponse>` payload.

  * `{:fault, code, message}` for method-not-found and other protocol errors.

  """
  @spec dispatch(String.t(), list()) :: {:ok, term()} | fault()
  def dispatch(method, params) do
    Logger.info("XML-RPC #{method} params=#{inspect(params)}")
    do_dispatch(method, params)
  end

  defp do_dispatch("blogger.getUsersBlogs", [_appkey, _username, _password]) do
    site = ElixirLocalize.site_config()

    blog = %{
      "blogid" => site[:base_url],
      "blogName" => site[:title],
      "url" => site[:base_url]
    }

    {:ok, [blog]}
  end

  defp do_dispatch("microblog.getPosts", params) do
    count = count_from(params, 3)
    {:ok, all_posts_as_structs(count)}
  end

  defp do_dispatch("metaWeblog.getRecentPosts", [_blog_id, _username, _password, count])
      when is_integer(count) do
    {:ok, all_posts_as_structs(count)}
  end

  defp do_dispatch("metaWeblog.getRecentPosts", [_blog_id, _username, _password]) do
    {:ok, all_posts_as_structs(50)}
  end

  defp do_dispatch("metaWeblog.getPost", [post_id, _username, _password]) do
    case lookup_post(post_id) do
      nil -> {:fault, 404, "Post not found"}
      post -> {:ok, post_to_struct(post)}
    end
  end

  defp do_dispatch("microblog.getPost", [post_id, _username, _password]) do
    do_dispatch("metaWeblog.getPost", [post_id, nil, nil])
  end

  defp do_dispatch("microblog.getPost", [post_id, _username, _password, _extra]) do
    do_dispatch("metaWeblog.getPost", [post_id, nil, nil])
  end

  defp do_dispatch(
         "metaWeblog.editPost",
         [post_id, _username, _password, %{} = struct, publish]
       ) do
    edit_post(post_id, struct, publish)
  end

  defp do_dispatch("metaWeblog.editPost", [post_id, _username, _password, %{} = struct]) do
    edit_post(post_id, struct, nil)
  end

  defp do_dispatch(
         "microblog.editPost",
         [post_id, _username, _password, %{} = struct, publish]
       ) do
    edit_post(post_id, struct, publish)
  end

  defp do_dispatch("microblog.editPost", [post_id, _username, _password, %{} = struct]) do
    edit_post(post_id, struct, nil)
  end

  defp do_dispatch(
         "microblog.newPost",
         [_blog_id, _username, _password, %{} = struct, _publish]
       ) do
    do_dispatch("metaWeblog.newPost", [nil, nil, nil, struct, true])
  end

  defp do_dispatch("microblog.deletePost", [_appkey, post_id, _username, _password, _publish]) do
    do_dispatch("blogger.deletePost", [nil, post_id, nil, nil, true])
  end

  defp do_dispatch("blogger.deletePost", [_appkey, post_id, _username, _password, _publish]) do
    case lookup_post(post_id) do
      nil ->
        {:fault, 404, "Post not found"}

      post ->
        case ElixirLocalize.Micropub.delete(post_url(post)) do
          :ok ->
            after_write!()
            {:ok, true}

          {:error, reason} ->
            {:fault, 500, "Delete failed: #{inspect(reason)}"}
        end
    end
  end

  defp do_dispatch(
         "metaWeblog.newPost",
         [_blog_id, _username, _password, %{} = struct, publish]
       ) do
    status =
      case status_from_struct(struct, publish) do
        nil -> :published
        "draft" -> :draft
        "published" -> :published
      end

    properties =
      struct_to_properties(struct)
      |> Map.put_new(:date, Date.utc_today())
      |> Map.put(:status, status)

    case ElixirLocalize.Micropub.create(properties) do
      {:ok, url} ->
        after_write!()

        case ElixirLocalize.Micropub.slug_from_url(url) do
          {:ok, slug} -> {:ok, :erlang.phash2(slug)}
          _ -> {:ok, url}
        end

      {:error, reason} ->
        {:fault, 400, "Create failed: #{inspect(reason)}"}
    end
  end

  defp do_dispatch("microblog.getPages", _params), do: {:ok, []}

  defp do_dispatch("wp.getPages", _params), do: {:ok, []}

  defp do_dispatch("wp.getPageList", _params), do: {:ok, []}

  defp do_dispatch("metaWeblog.getCategories", [_blog_id, _username, _password]) do
    tags =
      RuntimePosts.all()
      |> Enum.flat_map(& &1.tags)
      |> Enum.uniq()
      |> Enum.sort()

    {:ok,
     Enum.map(tags, fn tag ->
       %{
         "categoryId" => tag,
         "categoryName" => tag,
         "description" => tag,
         "htmlUrl" => "",
         "rssUrl" => ""
       }
     end)}
  end

  defp do_dispatch(method, _params) do
    {:fault, -32601, "Method #{method} is not supported"}
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  # MarsEdit returns the hashed integer id we sent in getRecentPosts; look it
  # up by matching the hash against every known post. Also accept raw slugs
  # as a fallback, so previously-cached entries and third-party clients still
  # work.
  defp lookup_post(post_id) when is_integer(post_id) do
    Enum.find(RuntimePosts.all(), fn post ->
      :erlang.phash2(post.slug) == post_id
    end)
  end

  defp lookup_post(post_id) when is_binary(post_id) do
    case RuntimePosts.by_slug(post_id) do
      %_{} = post ->
        post

      _ ->
        case Integer.parse(post_id) do
          {integer, ""} -> lookup_post(integer)
          _ -> nil
        end
    end
  end

  defp lookup_post(_), do: nil

  defp count_from(params, index) do
    case Enum.at(params, index) do
      count when is_integer(count) and count > 0 -> count
      _ -> 50
    end
  end

  defp all_posts_as_structs(count) do
    RuntimePosts.all()
    |> Enum.take(count)
    |> Enum.map(&post_to_struct/1)
  end

  defp post_to_struct(post) do
    url = post_url(post)
    created = datetime_to_xmlrpc(post.published_at)
    modified = datetime_to_xmlrpc(post.updated_at)

    # MarsEdit uses `postid` as the primary key in its local database.
    # WordPress XML-RPC sends it as <string>"1234"</string>, and MarsEdit's
    # own editPost calls echo it back the same way, so we must match —
    # sending <int> caused MarsEdit's row parser to drop downstream fields
    # (dates and modified dates) silently. We stringify the phash2 so the
    # wire type is `<string>` while the content is still a stable integer.
    id_integer = :erlang.phash2(post.slug)
    id_string = Integer.to_string(id_integer)

    # Return the raw markdown body rather than the rendered HTML. MarsEdit's
    # micro.blog blog type treats the post content as markdown and will
    # send markdown back on save — so we must start from markdown on the
    # way out, otherwise the source of truth on disk gets replaced with
    # HTML the first time a post is edited.
    description = ElixirLocalize.RuntimePosts.markdown_body(post.slug) || post.body

    %{
      "postid" => id_string,
      "post_id" => id_string,
      "id" => id_string,
      "userid" => "1",
      "title" => post.title,
      "description" => description,
      # MetaWeblog-style date fields
      "dateCreated" => created,
      "date_created_gmt" => created,
      "pubDate" => created,
      "dateModified" => modified,
      "date_modified_gmt" => modified,
      # wp.getPost-style date fields — MarsEdit's list columns key on
      # these in some blog-type profiles.
      "post_date" => created,
      "post_date_gmt" => created,
      "post_modified" => modified,
      "post_modified_gmt" => modified,
      "categories" => post.tags,
      "link" => url,
      "permaLink" => url,
      "post_status" => wp_status(post.status),
      "post_type" => "post",
      "wp_post_format" => "standard",
      "wp_slug" => post.slug,
      "wp_author_id" => "1",
      "wp_author_display_name" => post.author,
      "wp_password" => "",
      "sticky" => 0,
      "mt_allow_comments" => 0,
      "mt_allow_pings" => 0,
      "mt_keywords" => Enum.join(post.tags, ","),
      "mt_excerpt" => post.summary,
      "mt_text_more" => "",
      "custom_fields" => []
    }
  end

  defp post_url(post) do
    site = ElixirLocalize.site_config()
    base = String.trim_trailing(site[:base_url], "/")
    "#{base}/posts/#{post.slug}/"
  end

  # WordPress / MetaWeblog speak "publish" and "draft" for post status.
  # MarsEdit reads/writes those literals.
  defp wp_status(:published), do: "publish"
  defp wp_status(:draft), do: "draft"
  defp wp_status(_), do: "publish"

  defp status_from_wp("draft"), do: :draft
  defp status_from_wp("publish"), do: :published
  defp status_from_wp("published"), do: :published
  defp status_from_wp(_), do: nil

  defp edit_post(post_id, %{} = struct, publish) do
    case lookup_post(post_id) do
      nil ->
        {:fault, 404, "Post not found"}

      post ->
        replace = struct_to_replace_map(struct, publish)

        case ElixirLocalize.Micropub.update(post_url(post), replace, %{}, %{}) do
          {:ok, _url} ->
            after_write!()
            {:ok, true}

          {:error, reason} ->
            {:fault, 500, "Update failed: #{inspect(reason)}"}
        end
    end
  end

  defp struct_to_replace_map(struct, publish) do
    %{}
    |> put_replace("name", struct["title"])
    |> put_replace("content", struct["description"])
    |> put_replace("category", tags_from_struct(struct))
    |> put_replace("summary", struct["mt_excerpt"])
    |> put_replace("post-status", status_from_struct(struct, publish))
    |> put_replace("published", datetime_from_struct(struct))
  end

  # MarsEdit splits tags across the "Categories" (checklist) and "Tags"
  # (free-form comma string) fields. We treat them as the same flat list.
  # Whichever field the user edited, we read from both on save and the
  # union is stored as `post.tags`.
  defp tags_from_struct(struct) do
    from_categories =
      case struct["categories"] do
        list when is_list(list) -> list
        _ -> []
      end

    from_keywords =
      case struct["mt_keywords"] do
        nil ->
          []

        "" ->
          []

        string when is_binary(string) ->
          string
          |> String.split(",", trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        _ ->
          []
      end

    case Enum.uniq(from_categories ++ from_keywords) do
      [] -> nil
      tags -> tags
    end
  end

  defp datetime_from_struct(struct) do
    case struct["dateCreated"] || struct["date_created_gmt"] do
      %XMLRPC.DateTime{raw: raw} -> raw
      string when is_binary(string) -> string
      _ -> nil
    end
  end

  # Status precedence: explicit `post_status` field in the struct wins;
  # otherwise fall back to the boolean `publish` flag at the end of the
  # XML-RPC call. `nil` means "don't change".
  defp status_from_struct(struct, publish) do
    cond do
      is_binary(struct["post_status"]) ->
        status_from_wp(struct["post_status"]) |> to_micropub_status()

      publish == false ->
        "draft"

      publish == true ->
        "published"

      true ->
        nil
    end
  end

  defp to_micropub_status(:draft), do: "draft"
  defp to_micropub_status(:published), do: "published"
  defp to_micropub_status(_), do: nil

  defp put_replace(map, _key, nil), do: map
  defp put_replace(map, _key, ""), do: map
  defp put_replace(map, key, value) when is_list(value), do: Map.put(map, key, value)
  defp put_replace(map, key, value), do: Map.put(map, key, [value])

  defp struct_to_properties(struct) do
    %{}
    |> maybe_put(:title, struct["title"])
    |> maybe_put(:content, struct["description"])
    |> maybe_put(:tags, struct["categories"])
    |> maybe_put(:slug, struct["wp_slug"])
    |> maybe_put(:description, struct["mt_excerpt"])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, _key, []), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp after_write! do
    posts = RuntimePosts.all()
    output = Path.expand("_site")
    {:ok, _} = ElixirLocalize.Generator.build(output, posts)
    :ok
  end

  defp datetime_to_xmlrpc(%DateTime{} = datetime) do
    # The XML-RPC spec calls for basic ISO 8601 without a timezone
    # (YYYYMMDDTHH:MM:SS). In practice, Cocoa-based clients — MarsEdit
    # included — use `NSISO8601DateFormatter`, which accepts the extended
    # format with a `Z` timezone suffix (YYYY-MM-DDTHH:MM:SSZ) but
    # silently fails on the stricter basic form. We send the extended
    # form so MarsEdit can populate its Published / Edited columns.
    utc = DateTime.shift_zone!(datetime, "Etc/UTC")
    %XMLRPC.DateTime{raw: format_datetime(utc)}
  end

  defp datetime_to_xmlrpc(_), do: nil

  defp format_datetime(%DateTime{} = dt) do
    # XML-RPC dateTime.iso8601 basic format: YYYYMMDDTHH:MM:SS, no dashes,
    # no timezone. Matches what WordPress emits and what MarsEdit's legacy
    # WordPress date parser expects for list-view columns.
    :io_lib.format(
      "~4..0B~2..0B~2..0BT~2..0B:~2..0B:~2..0B",
      [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
    )
    |> IO.iodata_to_binary()
  end
end
