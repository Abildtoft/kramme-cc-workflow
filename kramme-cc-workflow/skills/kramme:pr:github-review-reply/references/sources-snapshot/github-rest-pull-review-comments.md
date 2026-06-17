REST API endpoints for pull request review comments - GitHub Docs

[Skip to main content](#main-content)

The REST API is now versioned. For more information, see "[About API versioning](/rest/overview/api-versions)."

# REST API endpoints for pull request review comments

Use the REST API to interact with pull request review comments.

## [About pull request review comments](#about-pull-request-review-comments)

Pull request review comments are comments made on a portion of the unified diff during a pull request review. These are different from commit comments and issue comments in a pull request. For more information, see [REST API endpoints for commit comments](/en/rest/commits/comments) and [REST API endpoints for issue comments](/en/rest/issues/comments).

## [List review comments in a repository](#list-review-comments-in-a-repository)

Lists review comments for all pull requests in a repository. By default, review comments are in ascending order by ID.

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github-commitcomment.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github-commitcomment.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github-commitcomment.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github-commitcomment.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "List review comments in a repository"](#list-review-comments-in-a-repository--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Pull requests" repository permissions (read)

This endpoint can be used without authentication or the aforementioned permissions if only public resources are requested.

### [Parameters for "List review comments in a repository"](#list-review-comments-in-a-repository--parameters)

Headers

| Name, Type, Description  |

|

`accept` string

Setting to `application/vnd.github+json` is recommended.

  |

Path parameters

| Name, Type, Description  |

|

`owner` string Required

The account owner of the repository. The name is not case sensitive.

  |

|

`repo` string Required

The name of the repository without the `.git` extension. The name is not case sensitive.

  |

Query parameters

| Name, Type, Description  |

|

`sort` string

Can be one of: `created`, `updated`, `created_at`   |

|

`direction` string

The direction to sort results. Ignored without `sort` parameter.

Can be one of: `asc`, `desc`   |

|

`since` string

Only show results that were last updated after the given time. This is a timestamp in [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) format: `YYYY-MM-DDTHH:MM:SSZ`.

  |

|

`per_page` integer

The number of results per page (max 100). For more information, see "[Using pagination in the REST API](https://docs.github.com/rest/using-the-rest-api/using-pagination-in-the-rest-api)."

Default: `30`  |

|

`page` integer

The page number of the results to fetch. For more information, see "[Using pagination in the REST API](https://docs.github.com/rest/using-the-rest-api/using-pagination-in-the-rest-api)."

Default: `1`  |

### [HTTP response status codes for "List review comments in a repository"](#list-review-comments-in-a-repository--status-codes)

| Status code | Description  |

| `200` |

OK  |

### [Code samples for "List review comments in a repository"](#list-review-comments-in-a-repository--code-samples)

#### Request example

get/repos/{owner}/{repo}/pulls/comments

-
-
-

Copy to clipboard curl request example

`curl -L \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/pulls/comments`

####

Response

-
-

`Status: 200`

`[ { "url": "https://api.github.com/repos/octocat/Hello-World/pulls/comments/1", "pull_request_review_id": 42, "id": 10, "node_id": "MDI0OlB1bGxSZXF1ZXN0UmV2aWV3Q29tbWVudDEw", "diff_hunk": "@@ -16,33 +16,40 @@ public class Connection : IConnection...", "path": "file1.txt", "position": 1, "original_position": 4, "commit_id": "6dcb09b5b57875f334f61aebed695e2e4193db5e", "original_commit_id": "9c48853fa3dc5c1c3d6f1f1cd1f2743e72652840", "in_reply_to_id": 8, "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "body": "Great stuff!", "created_at": "2011-04-14T16:00:49Z", "updated_at": "2011-04-14T16:00:49Z", "html_url": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1", "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/1", "author_association": "NONE", "_links": { "self": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/comments/1" }, "html": { "href": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1" }, "pull_request": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/1" } }, "start_line": 1, "original_start_line": 1, "start_side": "RIGHT", "line": 2, "original_line": 2, "side": "RIGHT" } ]`

## [Get a review comment for a pull request](#get-a-review-comment-for-a-pull-request)

Provides details for a specified review comment.

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github-commitcomment.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github-commitcomment.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github-commitcomment.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github-commitcomment.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "Get a review comment for a pull request"](#get-a-review-comment-for-a-pull-request--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Pull requests" repository permissions (read)

This endpoint can be used without authentication or the aforementioned permissions if only public resources are requested.

### [Parameters for "Get a review comment for a pull request"](#get-a-review-comment-for-a-pull-request--parameters)

Headers

| Name, Type, Description  |

|

`accept` string

Setting to `application/vnd.github+json` is recommended.

  |

Path parameters

| Name, Type, Description  |

|

`owner` string Required

The account owner of the repository. The name is not case sensitive.

  |

|

`repo` string Required

The name of the repository without the `.git` extension. The name is not case sensitive.

  |

|

`comment_id` integer Required

The unique identifier of the comment.

  |

### [HTTP response status codes for "Get a review comment for a pull request"](#get-a-review-comment-for-a-pull-request--status-codes)

| Status code | Description  |

| `200` |

OK  |

| `404` |

Resource not found  |

### [Code samples for "Get a review comment for a pull request"](#get-a-review-comment-for-a-pull-request--code-samples)

#### Request example

get/repos/{owner}/{repo}/pulls/comments/{comment_id}

-
-
-

Copy to clipboard curl request example

`curl -L \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/pulls/comments/COMMENT_ID`

####

Response

-
-

`Status: 200`

`{ "url": "https://api.github.com/repos/octocat/Hello-World/pulls/comments/1", "pull_request_review_id": 42, "id": 10, "node_id": "MDI0OlB1bGxSZXF1ZXN0UmV2aWV3Q29tbWVudDEw", "diff_hunk": "@@ -16,33 +16,40 @@ public class Connection : IConnection...", "path": "file1.txt", "position": 1, "original_position": 4, "commit_id": "6dcb09b5b57875f334f61aebed695e2e4193db5e", "original_commit_id": "9c48853fa3dc5c1c3d6f1f1cd1f2743e72652840", "in_reply_to_id": 8, "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "body": "Great stuff!", "created_at": "2011-04-14T16:00:49Z", "updated_at": "2011-04-14T16:00:49Z", "html_url": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1", "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/1", "author_association": "NONE", "_links": { "self": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/comments/1" }, "html": { "href": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1" }, "pull_request": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/1" } }, "start_line": 1, "original_start_line": 1, "start_side": "RIGHT", "line": 2, "original_line": 2, "side": "RIGHT" }`

## [Update a review comment for a pull request](#update-a-review-comment-for-a-pull-request)

Edits the content of a specified review comment.

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github-commitcomment.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github-commitcomment.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github-commitcomment.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github-commitcomment.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "Update a review comment for a pull request"](#update-a-review-comment-for-a-pull-request--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Pull requests" repository permissions (write)

### [Parameters for "Update a review comment for a pull request"](#update-a-review-comment-for-a-pull-request--parameters)

Headers

| Name, Type, Description  |

|

`accept` string

Setting to `application/vnd.github+json` is recommended.

  |

Path parameters

| Name, Type, Description  |

|

`owner` string Required

The account owner of the repository. The name is not case sensitive.

  |

|

`repo` string Required

The name of the repository without the `.git` extension. The name is not case sensitive.

  |

|

`comment_id` integer Required

The unique identifier of the comment.

  |

Body parameters

| Name, Type, Description  |

|

`body` string Required

The text of the reply to the review comment.

  |

### [HTTP response status codes for "Update a review comment for a pull request"](#update-a-review-comment-for-a-pull-request--status-codes)

| Status code | Description  |

| `200` |

OK  |

### [Code samples for "Update a review comment for a pull request"](#update-a-review-comment-for-a-pull-request--code-samples)

#### Request example

patch/repos/{owner}/{repo}/pulls/comments/{comment_id}

-
-
-

Copy to clipboard curl request example

`curl -L \ -X PATCH \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/pulls/comments/COMMENT_ID \ -d '{"body":"I like this too!"}'`

####

Response

-
-

`Status: 200`

`{ "url": "https://api.github.com/repos/octocat/Hello-World/pulls/comments/1", "pull_request_review_id": 42, "id": 10, "node_id": "MDI0OlB1bGxSZXF1ZXN0UmV2aWV3Q29tbWVudDEw", "diff_hunk": "@@ -16,33 +16,40 @@ public class Connection : IConnection...", "path": "file1.txt", "position": 1, "original_position": 4, "commit_id": "6dcb09b5b57875f334f61aebed695e2e4193db5e", "original_commit_id": "9c48853fa3dc5c1c3d6f1f1cd1f2743e72652840", "in_reply_to_id": 8, "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "body": "Great stuff!", "created_at": "2011-04-14T16:00:49Z", "updated_at": "2011-04-14T16:00:49Z", "html_url": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1", "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/1", "author_association": "NONE", "_links": { "self": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/comments/1" }, "html": { "href": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1" }, "pull_request": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/1" } }, "start_line": 1, "original_start_line": 1, "start_side": "RIGHT", "line": 2, "original_line": 2, "side": "RIGHT" }`

## [Delete a review comment for a pull request](#delete-a-review-comment-for-a-pull-request)

Deletes a review comment.

### [Fine-grained access tokens for "Delete a review comment for a pull request"](#delete-a-review-comment-for-a-pull-request--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Pull requests" repository permissions (write)

### [Parameters for "Delete a review comment for a pull request"](#delete-a-review-comment-for-a-pull-request--parameters)

Headers

| Name, Type, Description  |

|

`accept` string

Setting to `application/vnd.github+json` is recommended.

  |

Path parameters

| Name, Type, Description  |

|

`owner` string Required

The account owner of the repository. The name is not case sensitive.

  |

|

`repo` string Required

The name of the repository without the `.git` extension. The name is not case sensitive.

  |

|

`comment_id` integer Required

The unique identifier of the comment.

  |

### [HTTP response status codes for "Delete a review comment for a pull request"](#delete-a-review-comment-for-a-pull-request--status-codes)

| Status code | Description  |

| `204` |

No Content  |

| `404` |

Resource not found  |

### [Code samples for "Delete a review comment for a pull request"](#delete-a-review-comment-for-a-pull-request--code-samples)

#### Request example

delete/repos/{owner}/{repo}/pulls/comments/{comment_id}

-
-
-

Copy to clipboard curl request example

`curl -L \ -X DELETE \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/pulls/comments/COMMENT_ID`

####

Response

`Status: 204`

## [List review comments on a pull request](#list-review-comments-on-a-pull-request)

Lists all review comments for a specified pull request. By default, review comments are in ascending order by ID.

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github-commitcomment.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github-commitcomment.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github-commitcomment.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github-commitcomment.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "List review comments on a pull request"](#list-review-comments-on-a-pull-request--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Pull requests" repository permissions (read)

This endpoint can be used without authentication or the aforementioned permissions if only public resources are requested.

### [Parameters for "List review comments on a pull request"](#list-review-comments-on-a-pull-request--parameters)

Headers

| Name, Type, Description  |

|

`accept` string

Setting to `application/vnd.github+json` is recommended.

  |

Path parameters

| Name, Type, Description  |

|

`owner` string Required

The account owner of the repository. The name is not case sensitive.

  |

|

`repo` string Required

The name of the repository without the `.git` extension. The name is not case sensitive.

  |

|

`pull_number` integer Required

The number that identifies the pull request.

  |

Query parameters

| Name, Type, Description  |

|

`sort` string

The property to sort the results by.

Default: `created`

Can be one of: `created`, `updated`   |

|

`direction` string

The direction to sort results. Ignored without `sort` parameter.

Can be one of: `asc`, `desc`   |

|

`since` string

Only show results that were last updated after the given time. This is a timestamp in [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) format: `YYYY-MM-DDTHH:MM:SSZ`.

  |

|

`per_page` integer

The number of results per page (max 100). For more information, see "[Using pagination in the REST API](https://docs.github.com/rest/using-the-rest-api/using-pagination-in-the-rest-api)."

Default: `30`  |

|

`page` integer

The page number of the results to fetch. For more information, see "[Using pagination in the REST API](https://docs.github.com/rest/using-the-rest-api/using-pagination-in-the-rest-api)."

Default: `1`  |

### [HTTP response status codes for "List review comments on a pull request"](#list-review-comments-on-a-pull-request--status-codes)

| Status code | Description  |

| `200` |

OK  |

### [Code samples for "List review comments on a pull request"](#list-review-comments-on-a-pull-request--code-samples)

#### Request example

get/repos/{owner}/{repo}/pulls/{pull_number}/comments

-
-
-

Copy to clipboard curl request example

`curl -L \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/pulls/PULL_NUMBER/comments`

####

Response

-
-

`Status: 200`

`[ { "url": "https://api.github.com/repos/octocat/Hello-World/pulls/comments/1", "pull_request_review_id": 42, "id": 10, "node_id": "MDI0OlB1bGxSZXF1ZXN0UmV2aWV3Q29tbWVudDEw", "diff_hunk": "@@ -16,33 +16,40 @@ public class Connection : IConnection...", "path": "file1.txt", "position": 1, "original_position": 4, "commit_id": "6dcb09b5b57875f334f61aebed695e2e4193db5e", "original_commit_id": "9c48853fa3dc5c1c3d6f1f1cd1f2743e72652840", "in_reply_to_id": 8, "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "body": "Great stuff!", "created_at": "2011-04-14T16:00:49Z", "updated_at": "2011-04-14T16:00:49Z", "html_url": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1", "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/1", "author_association": "NONE", "_links": { "self": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/comments/1" }, "html": { "href": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1" }, "pull_request": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/1" } }, "start_line": 1, "original_start_line": 1, "start_side": "RIGHT", "line": 2, "original_line": 2, "side": "RIGHT" } ]`

## [Create a review comment for a pull request](#create-a-review-comment-for-a-pull-request)

Creates a review comment on the diff of a specified pull request. To add a regular comment to a pull request timeline, see "[Create an issue comment](https://docs.github.com/rest/issues/comments#create-an-issue-comment)."

If your comment applies to more than one line in the pull request diff, you should use the parameters `line`, `side`, and optionally `start_line` and `start_side` in your request.

The `position` parameter is closing down. If you use `position`, the `line`, `side`, `start_line`, and `start_side` parameters are not required.

This endpoint triggers [notifications](https://docs.github.com/github/managing-subscriptions-and-notifications-on-github/about-notifications). Creating content too quickly using this endpoint may result in secondary rate limiting. For more information, see "[Rate limits for the API](https://docs.github.com/rest/using-the-rest-api/rate-limits-for-the-rest-api#about-secondary-rate-limits)" and "[Best practices for using the REST API](https://docs.github.com/rest/guides/best-practices-for-using-the-rest-api)."

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github-commitcomment.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github-commitcomment.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github-commitcomment.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github-commitcomment.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "Create a review comment for a pull request"](#create-a-review-comment-for-a-pull-request--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Pull requests" repository permissions (write)

### [Parameters for "Create a review comment for a pull request"](#create-a-review-comment-for-a-pull-request--parameters)

Headers

| Name, Type, Description  |

|

`accept` string

Setting to `application/vnd.github+json` is recommended.

  |

Path parameters

| Name, Type, Description  |

|

`owner` string Required

The account owner of the repository. The name is not case sensitive.

  |

|

`repo` string Required

The name of the repository without the `.git` extension. The name is not case sensitive.

  |

|

`pull_number` integer Required

The number that identifies the pull request.

  |

Body parameters

| Name, Type, Description  |

|

`body` string Required

The text of the review comment.

  |

|

`commit_id` string Required

The SHA of the commit needing a comment. Not using the latest commit SHA may render your comment outdated if a subsequent commit modifies the line you specify as the `position`.

  |

|

`path` string Required

The relative path to the file that necessitates a comment.

  |

|

`position` integer

This parameter is closing down. Use `line` instead. The position in the diff where you want to add a review comment. Note this value is not the same as the line number in the file. The position value equals the number of lines down from the first "@@" hunk header in the file you want to add a comment. The line just below the "@@" line is position 1, the next line is position 2, and so on. The position in the diff continues to increase through lines of whitespace and additional hunks until the beginning of a new file.

  |

|

`side` string

In a split diff view, the side of the diff that the pull request's changes appear on. Can be `LEFT` or `RIGHT`. Use `LEFT` for deletions that appear in red. Use `RIGHT` for additions that appear in green or unchanged lines that appear in white and are shown for context. For a multi-line comment, side represents whether the last line of the comment range is a deletion or addition. For more information, see "[Diff view options](https://docs.github.com/articles/about-comparing-branches-in-pull-requests#diff-view-options)" in the GitHub Help documentation.

Can be one of: `LEFT`, `RIGHT`   |

|

`line` integer

Required unless using `subject_type:file`. The line of the blob in the pull request diff that the comment applies to. For a multi-line comment, the last line of the range that your comment applies to.

  |

|

`start_line` integer

Required when using multi-line comments unless using `in_reply_to`. The `start_line` is the first line in the pull request diff that your multi-line comment applies to. To learn more about multi-line comments, see "[Commenting on a pull request](https://docs.github.com/articles/commenting-on-a-pull-request#adding-line-comments-to-a-pull-request)" in the GitHub Help documentation.

  |

|

`start_side` string

Required when using multi-line comments unless using `in_reply_to`. The `start_side` is the starting side of the diff that the comment applies to. Can be `LEFT` or `RIGHT`. To learn more about multi-line comments, see "[Commenting on a pull request](https://docs.github.com/articles/commenting-on-a-pull-request#adding-line-comments-to-a-pull-request)" in the GitHub Help documentation. See `side` in this table for additional context.

Can be one of: `LEFT`, `RIGHT`, `side`   |

|

`in_reply_to` integer

The ID of the review comment to reply to. To find the ID of a review comment with ["List review comments on a pull request"](#list-review-comments-on-a-pull-request). When specified, all parameters other than `body` in the request body are ignored.

  |

|

`subject_type` string

The level at which the comment is targeted.

Can be one of: `line`, `file`   |

### [HTTP response status codes for "Create a review comment for a pull request"](#create-a-review-comment-for-a-pull-request--status-codes)

| Status code | Description  |

| `201` |

Created  |

| `403` |

Forbidden  |

| `422` |

Validation failed, or the endpoint has been spammed.  |

### [Code samples for "Create a review comment for a pull request"](#create-a-review-comment-for-a-pull-request--code-samples)

#### Request example

post/repos/{owner}/{repo}/pulls/{pull_number}/comments

-
-
-

Copy to clipboard curl request example

`curl -L \ -X POST \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/pulls/PULL_NUMBER/comments \ -d '{"body":"Great stuff!","commit_id":"6dcb09b5b57875f334f61aebed695e2e4193db5e","path":"file1.txt","start_line":1,"start_side":"RIGHT","line":2,"side":"RIGHT"}'`

####

Response

-
-

`Status: 201`

`{ "url": "https://api.github.com/repos/octocat/Hello-World/pulls/comments/1", "pull_request_review_id": 42, "id": 10, "node_id": "MDI0OlB1bGxSZXF1ZXN0UmV2aWV3Q29tbWVudDEw", "diff_hunk": "@@ -16,33 +16,40 @@ public class Connection : IConnection...", "path": "file1.txt", "position": 1, "original_position": 4, "commit_id": "6dcb09b5b57875f334f61aebed695e2e4193db5e", "original_commit_id": "9c48853fa3dc5c1c3d6f1f1cd1f2743e72652840", "in_reply_to_id": 8, "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "body": "Great stuff!", "created_at": "2011-04-14T16:00:49Z", "updated_at": "2011-04-14T16:00:49Z", "html_url": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1", "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/1", "author_association": "NONE", "_links": { "self": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/comments/1" }, "html": { "href": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1" }, "pull_request": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/1" } }, "start_line": 1, "original_start_line": 1, "start_side": "RIGHT", "line": 2, "original_line": 2, "side": "RIGHT" }`

## [Create a reply for a review comment](#create-a-reply-for-a-review-comment)

Creates a reply to a review comment for a pull request. For the `comment_id`, provide the ID of the review comment you are replying to. This must be the ID of a top-level review comment, not a reply to that comment. Replies to replies are not supported.

This endpoint triggers [notifications](https://docs.github.com/github/managing-subscriptions-and-notifications-on-github/about-notifications). Creating content too quickly using this endpoint may result in secondary rate limiting. For more information, see "[Rate limits for the API](https://docs.github.com/rest/using-the-rest-api/rate-limits-for-the-rest-api#about-secondary-rate-limits)" and "[Best practices for using the REST API](https://docs.github.com/rest/guides/best-practices-for-using-the-rest-api)."

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github-commitcomment.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github-commitcomment.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github-commitcomment.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github-commitcomment.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "Create a reply for a review comment"](#create-a-reply-for-a-review-comment--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Pull requests" repository permissions (write)

### [Parameters for "Create a reply for a review comment"](#create-a-reply-for-a-review-comment--parameters)

Headers

| Name, Type, Description  |

|

`accept` string

Setting to `application/vnd.github+json` is recommended.

  |

Path parameters

| Name, Type, Description  |

|

`owner` string Required

The account owner of the repository. The name is not case sensitive.

  |

|

`repo` string Required

The name of the repository without the `.git` extension. The name is not case sensitive.

  |

|

`pull_number` integer Required

The number that identifies the pull request.

  |

|

`comment_id` integer Required

The unique identifier of the comment.

  |

Body parameters

| Name, Type, Description  |

|

`body` string Required

The text of the review comment.

  |

### [HTTP response status codes for "Create a reply for a review comment"](#create-a-reply-for-a-review-comment--status-codes)

| Status code | Description  |

| `201` |

Created  |

| `404` |

Resource not found  |

### [Code samples for "Create a reply for a review comment"](#create-a-reply-for-a-review-comment--code-samples)

#### Request example

post/repos/{owner}/{repo}/pulls/{pull_number}/comments/{comment_id}/replies

-
-
-

Copy to clipboard curl request example

`curl -L \ -X POST \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/pulls/PULL_NUMBER/comments/COMMENT_ID/replies \ -d '{"body":"Great stuff!"}'`

####

Response

-
-

`Status: 201`

`{ "url": "https://api.github.com/repos/octocat/Hello-World/pulls/comments/1", "pull_request_review_id": 42, "id": 10, "node_id": "MDI0OlB1bGxSZXF1ZXN0UmV2aWV3Q29tbWVudDEw", "diff_hunk": "@@ -16,33 +16,40 @@ public class Connection : IConnection...", "path": "file1.txt", "position": 1, "original_position": 4, "commit_id": "6dcb09b5b57875f334f61aebed695e2e4193db5e", "original_commit_id": "9c48853fa3dc5c1c3d6f1f1cd1f2743e72652840", "in_reply_to_id": 426899381, "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "body": "Great stuff!", "created_at": "2011-04-14T16:00:49Z", "updated_at": "2011-04-14T16:00:49Z", "html_url": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1", "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/1", "author_association": "NONE", "_links": { "self": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/comments/1" }, "html": { "href": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1" }, "pull_request": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/1" } }, "start_line": 1, "original_start_line": 1, "start_side": "RIGHT", "line": 2, "original_line": 2, "side": "RIGHT" }`
