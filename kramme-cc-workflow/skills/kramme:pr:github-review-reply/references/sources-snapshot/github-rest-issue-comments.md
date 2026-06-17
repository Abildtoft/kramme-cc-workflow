REST API endpoints for issue comments - GitHub Docs

[Skip to main content](#main-content)

The REST API is now versioned. For more information, see "[About API versioning](/rest/overview/api-versions)."

# REST API endpoints for issue comments

Use the REST API to manage comments on issues and pull requests.

## [About issue and pull request comments](#about-issue-and-pull-request-comments)

You can use the REST API to create and manage comments on issues and pull requests. Every pull request is an issue, but not every issue is a pull request. For this reason, "shared" actions for both features, like managing assignees, labels, and milestones, are provided within the Issues endpoints. To manage pull request review comments, see [REST API endpoints for pull request review comments](/en/rest/pulls/comments).

## [List issue comments for a repository](#list-issue-comments-for-a-repository)

You can use the REST API to list comments on issues and pull requests for a repository. Every pull request is an issue, but not every issue is a pull request.

By default, issue comments are ordered by ascending ID.

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "List issue comments for a repository"](#list-issue-comments-for-a-repository--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have at least one of the following permission sets:

- "Issues" repository permissions (read)
- "Pull requests" repository permissions (read)

This endpoint can be used without authentication or the aforementioned permissions if only public resources are requested.

### [Parameters for "List issue comments for a repository"](#list-issue-comments-for-a-repository--parameters)

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

The property to sort the results by.

Default: `created`

Can be one of: `created`, `updated`   |

|

`direction` string

Either `asc` or `desc`. Ignored without the `sort` parameter.

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

### [HTTP response status codes for "List issue comments for a repository"](#list-issue-comments-for-a-repository--status-codes)

| Status code | Description  |

| `200` |

OK  |

| `404` |

Resource not found  |

| `422` |

Validation failed, or the endpoint has been spammed.  |

### [Code samples for "List issue comments for a repository"](#list-issue-comments-for-a-repository--code-samples)

#### Request example

get/repos/{owner}/{repo}/issues/comments

-
-
-

Copy to clipboard curl request example

`curl -L \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/issues/comments`

####

Response

-
-

`Status: 200`

`[ { "id": 1, "node_id": "MDEyOklzc3VlQ29tbWVudDE=", "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1", "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1", "body": "Me too", "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "created_at": "2011-04-14T16:00:49Z", "updated_at": "2011-04-14T16:00:49Z", "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347", "author_association": "COLLABORATOR" } ]`

## [Get an issue comment](#get-an-issue-comment)

You can use the REST API to get comments on issues and pull requests. Every pull request is an issue, but not every issue is a pull request.

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "Get an issue comment"](#get-an-issue-comment--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have at least one of the following permission sets:

- "Issues" repository permissions (read)
- "Pull requests" repository permissions (read)

This endpoint can be used without authentication or the aforementioned permissions if only public resources are requested.

### [Parameters for "Get an issue comment"](#get-an-issue-comment--parameters)

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

### [HTTP response status codes for "Get an issue comment"](#get-an-issue-comment--status-codes)

| Status code | Description  |

| `200` |

OK  |

| `404` |

Resource not found  |

### [Code samples for "Get an issue comment"](#get-an-issue-comment--code-samples)

#### Request example

get/repos/{owner}/{repo}/issues/comments/{comment_id}

-
-
-

Copy to clipboard curl request example

`curl -L \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/issues/comments/COMMENT_ID`

####

Response

-
-

`Status: 200`

`{ "id": 1, "node_id": "MDEyOklzc3VlQ29tbWVudDE=", "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1", "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1", "body": "Me too", "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "created_at": "2011-04-14T16:00:49Z", "updated_at": "2011-04-14T16:00:49Z", "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347", "author_association": "COLLABORATOR", "pin": null }`

## [Update an issue comment](#update-an-issue-comment)

You can use the REST API to update comments on issues and pull requests. Every pull request is an issue, but not every issue is a pull request.

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "Update an issue comment"](#update-an-issue-comment--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have at least one of the following permission sets:

- "Issues" repository permissions (write)
- "Pull requests" repository permissions (write)

### [Parameters for "Update an issue comment"](#update-an-issue-comment--parameters)

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

The contents of the comment.

  |

### [HTTP response status codes for "Update an issue comment"](#update-an-issue-comment--status-codes)

| Status code | Description  |

| `200` |

OK  |

| `422` |

Validation failed, or the endpoint has been spammed.  |

### [Code samples for "Update an issue comment"](#update-an-issue-comment--code-samples)

#### Request example

patch/repos/{owner}/{repo}/issues/comments/{comment_id}

-
-
-

Copy to clipboard curl request example

`curl -L \ -X PATCH \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/issues/comments/COMMENT_ID \ -d '{"body":"Me too"}'`

####

Response

-
-

`Status: 200`

`{ "id": 1, "node_id": "MDEyOklzc3VlQ29tbWVudDE=", "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1", "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1", "body": "Me too", "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "created_at": "2011-04-14T16:00:49Z", "updated_at": "2011-04-14T16:00:49Z", "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347", "author_association": "COLLABORATOR", "pin": null }`

## [Delete an issue comment](#delete-an-issue-comment)

You can use the REST API to delete comments on issues and pull requests. Every pull request is an issue, but not every issue is a pull request.

### [Fine-grained access tokens for "Delete an issue comment"](#delete-an-issue-comment--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have at least one of the following permission sets:

- "Issues" repository permissions (write)
- "Pull requests" repository permissions (write)

### [Parameters for "Delete an issue comment"](#delete-an-issue-comment--parameters)

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

### [HTTP response status codes for "Delete an issue comment"](#delete-an-issue-comment--status-codes)

| Status code | Description  |

| `204` |

No Content  |

### [Code samples for "Delete an issue comment"](#delete-an-issue-comment--code-samples)

#### Request example

delete/repos/{owner}/{repo}/issues/comments/{comment_id}

-
-
-

Copy to clipboard curl request example

`curl -L \ -X DELETE \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/issues/comments/COMMENT_ID`

####

Response

`Status: 204`

## [Pin an issue comment](#pin-an-issue-comment)

You can use the REST API to pin comments on issues.

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "Pin an issue comment"](#pin-an-issue-comment--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Issues" repository permissions (write)

### [Parameters for "Pin an issue comment"](#pin-an-issue-comment--parameters)

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

### [HTTP response status codes for "Pin an issue comment"](#pin-an-issue-comment--status-codes)

| Status code | Description  |

| `200` |

OK  |

| `401` |

Requires authentication  |

| `403` |

Forbidden  |

| `404` |

Resource not found  |

| `410` |

Gone  |

| `422` |

Validation failed, or the endpoint has been spammed.  |

### [Code samples for "Pin an issue comment"](#pin-an-issue-comment--code-samples)

#### Request example

put/repos/{owner}/{repo}/issues/comments/{comment_id}/pin

-
-
-

Copy to clipboard curl request example

`curl -L \ -X PUT \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/issues/comments/COMMENT_ID/pin`

####

Response

-
-

`Status: 200`

`{ "id": 1, "node_id": "MDEyOklzc3VlQ29tbWVudDE=", "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1", "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1", "body": "Me too", "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "created_at": "2011-04-14T16:00:49Z", "updated_at": "2011-04-14T16:00:49Z", "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347", "author_association": "COLLABORATOR", "pin": { "pinned_at": "2021-01-01T00:00:00Z", "pinned_by": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false } } }`

## [Unpin an issue comment](#unpin-an-issue-comment)

You can use the REST API to unpin comments on issues.

### [Fine-grained access tokens for "Unpin an issue comment"](#unpin-an-issue-comment--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Issues" repository permissions (write)

### [Parameters for "Unpin an issue comment"](#unpin-an-issue-comment--parameters)

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

### [HTTP response status codes for "Unpin an issue comment"](#unpin-an-issue-comment--status-codes)

| Status code | Description  |

| `204` |

No Content  |

| `401` |

Requires authentication  |

| `403` |

Forbidden  |

| `404` |

Resource not found  |

| `410` |

Gone  |

| `503` |

Service unavailable  |

### [Code samples for "Unpin an issue comment"](#unpin-an-issue-comment--code-samples)

#### Request example

delete/repos/{owner}/{repo}/issues/comments/{comment_id}/pin

-
-
-

Copy to clipboard curl request example

`curl -L \ -X DELETE \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/issues/comments/COMMENT_ID/pin`

####

Response

`Status: 204`

## [List issue comments](#list-issue-comments)

You can use the REST API to list comments on issues and pull requests. Every pull request is an issue, but not every issue is a pull request.

Issue comments are ordered by ascending ID.

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "List issue comments"](#list-issue-comments--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have at least one of the following permission sets:

- "Issues" repository permissions (read)
- "Pull requests" repository permissions (read)

This endpoint can be used without authentication or the aforementioned permissions if only public resources are requested.

### [Parameters for "List issue comments"](#list-issue-comments--parameters)

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

`issue_number` integer Required

The number that identifies the issue.

  |

Query parameters

| Name, Type, Description  |

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

### [HTTP response status codes for "List issue comments"](#list-issue-comments--status-codes)

| Status code | Description  |

| `200` |

OK  |

| `404` |

Resource not found  |

| `410` |

Gone  |

### [Code samples for "List issue comments"](#list-issue-comments--code-samples)

#### Request example

get/repos/{owner}/{repo}/issues/{issue_number}/comments

-
-
-

Copy to clipboard curl request example

`curl -L \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/issues/ISSUE_NUMBER/comments`

####

Response

-
-

`Status: 200`

`[ { "id": 1, "node_id": "MDEyOklzc3VlQ29tbWVudDE=", "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1", "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1", "body": "Me too", "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "created_at": "2011-04-14T16:00:49Z", "updated_at": "2011-04-14T16:00:49Z", "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347", "author_association": "COLLABORATOR" } ]`

## [Create an issue comment](#create-an-issue-comment)

You can use the REST API to create comments on issues and pull requests. Every pull request is an issue, but not every issue is a pull request.

This endpoint triggers [notifications](https://docs.github.com/github/managing-subscriptions-and-notifications-on-github/about-notifications). Creating content too quickly using this endpoint may result in secondary rate limiting. For more information, see "[Rate limits for the API](https://docs.github.com/rest/using-the-rest-api/rate-limits-for-the-rest-api#about-secondary-rate-limits)" and "[Best practices for using the REST API](https://docs.github.com/rest/guides/best-practices-for-using-the-rest-api)."

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "Create an issue comment"](#create-an-issue-comment--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have at least one of the following permission sets:

- "Issues" repository permissions (write)
- "Pull requests" repository permissions (write)

### [Parameters for "Create an issue comment"](#create-an-issue-comment--parameters)

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

`issue_number` integer Required

The number that identifies the issue.

  |

Body parameters

| Name, Type, Description  |

|

`body` string Required

The contents of the comment.

  |

### [HTTP response status codes for "Create an issue comment"](#create-an-issue-comment--status-codes)

| Status code | Description  |

| `201` |

Created  |

| `403` |

Forbidden  |

| `404` |

Resource not found  |

| `410` |

Gone  |

| `422` |

Validation failed, or the endpoint has been spammed.  |

### [Code samples for "Create an issue comment"](#create-an-issue-comment--code-samples)

#### Request example

post/repos/{owner}/{repo}/issues/{issue_number}/comments

-
-
-

Copy to clipboard curl request example

`curl -L \ -X POST \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/issues/ISSUE_NUMBER/comments \ -d '{"body":"Me too"}'`

####

Response

-
-

`Status: 201`

`{ "id": 1, "node_id": "MDEyOklzc3VlQ29tbWVudDE=", "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1", "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1", "body": "Me too", "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "created_at": "2011-04-14T16:00:49Z", "updated_at": "2011-04-14T16:00:49Z", "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347", "author_association": "COLLABORATOR", "pin": null }`
