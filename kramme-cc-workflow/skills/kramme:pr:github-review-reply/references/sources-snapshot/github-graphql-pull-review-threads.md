Pull requests - GitHub Docs

[Skip to main content](#main-content)

# Pull requests

Reference documentation for GraphQL schema types in the Pull requests category.

## In this article

## [Mutations](#mutations)

### [addPullRequestCreationCapBypassUsers](#mutation-addpullrequestcreationcapbypassusers)

Mutation

Add users to the pull request creation cap bypass list. Bypassed users can create pull requests regardless of the configured cap. Only repository admins can manage the bypass list. You can add a maximum of 100 users per request. The bypass list can only hold a maximum of 100 users.

#### Input fields for `addPullRequestCreationCapBypassUsers`

- `input` (`[AddPullRequestCreationCapBypassUsersInput!](/en/graphql/reference/pulls#input-object-addpullrequestcreationcapbypassusersinput)`)

#### Return fields for `addPullRequestCreationCapBypassUsers`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`repository` (`[Repository](/en/graphql/reference/repos#object-repository)`) |

The repository with the updated bypass list.  |

### [addPullRequestReview](#mutation-addpullrequestreview)

Mutation

Adds a review to a Pull Request.

#### Input fields for `addPullRequestReview`

- `input` (`[AddPullRequestReviewInput!](/en/graphql/reference/pulls#input-object-addpullrequestreviewinput)`)

#### Return fields for `addPullRequestReview`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestReview` (`[PullRequestReview](/en/graphql/reference/pulls#object-pullrequestreview)`) |

The newly created pull request review.  |

|

`reviewEdge` (`[PullRequestReviewEdge](/en/graphql/reference/pulls#object-pullrequestreviewedge)`) |

The edge from the pull request's review connection.  |

### [addPullRequestReviewComment](#mutation-addpullrequestreviewcomment)

Mutation

Adds a comment to a review.

#### Input fields for `addPullRequestReviewComment`

- `input` (`[AddPullRequestReviewCommentInput!](/en/graphql/reference/pulls#input-object-addpullrequestreviewcommentinput)`)

#### Return fields for `addPullRequestReviewComment`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`comment` (`[PullRequestReviewComment](/en/graphql/reference/pulls#object-pullrequestreviewcomment)`) |

The newly created comment.  |

|

`commentEdge` (`[PullRequestReviewCommentEdge](/en/graphql/reference/pulls#object-pullrequestreviewcommentedge)`) |

The edge from the review's comment connection.  |

### [addPullRequestReviewThread](#mutation-addpullrequestreviewthread)

Mutation

Adds a new thread to a pending Pull Request Review.

#### Input fields for `addPullRequestReviewThread`

- `input` (`[AddPullRequestReviewThreadInput!](/en/graphql/reference/pulls#input-object-addpullrequestreviewthreadinput)`)

#### Return fields for `addPullRequestReviewThread`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`thread` (`[PullRequestReviewThread](/en/graphql/reference/pulls#object-pullrequestreviewthread)`) |

The newly created thread.  |

### [addPullRequestReviewThreadReply](#mutation-addpullrequestreviewthreadreply)

Mutation

Adds a reply to an existing Pull Request Review Thread.

#### Input fields for `addPullRequestReviewThreadReply`

- `input` (`[AddPullRequestReviewThreadReplyInput!](/en/graphql/reference/pulls#input-object-addpullrequestreviewthreadreplyinput)`)

#### Return fields for `addPullRequestReviewThreadReply`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`comment` (`[PullRequestReviewComment](/en/graphql/reference/pulls#object-pullrequestreviewcomment)`) |

The newly created reply.  |

### [archivePullRequest](#mutation-archivepullrequest)

Mutation

Archive a pull request. Closes, locks, and marks the pull request as archived. Only repository admins can archive pull requests.

#### Input fields for `archivePullRequest`

- `input` (`[ArchivePullRequestInput!](/en/graphql/reference/pulls#input-object-archivepullrequestinput)`)

#### Return fields for `archivePullRequest`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request that was archived.  |

### [closePullRequest](#mutation-closepullrequest)

Mutation

Close a pull request.

#### Input fields for `closePullRequest`

- `input` (`[ClosePullRequestInput!](/en/graphql/reference/pulls#input-object-closepullrequestinput)`)

#### Return fields for `closePullRequest`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request that was closed.  |

### [convertPullRequestToDraft](#mutation-convertpullrequesttodraft)

Mutation

Converts a pull request to draft.

#### Input fields for `convertPullRequestToDraft`

- `input` (`[ConvertPullRequestToDraftInput!](/en/graphql/reference/pulls#input-object-convertpullrequesttodraftinput)`)

#### Return fields for `convertPullRequestToDraft`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request that is now a draft.  |

### [createPullRequest](#mutation-createpullrequest)

Mutation

Create a new pull request.

#### Input fields for `createPullRequest`

- `input` (`[CreatePullRequestInput!](/en/graphql/reference/pulls#input-object-createpullrequestinput)`)

#### Return fields for `createPullRequest`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The new pull request.  |

### [deletePullRequestReview](#mutation-deletepullrequestreview)

Mutation

Deletes a pull request review.

#### Input fields for `deletePullRequestReview`

- `input` (`[DeletePullRequestReviewInput!](/en/graphql/reference/pulls#input-object-deletepullrequestreviewinput)`)

#### Return fields for `deletePullRequestReview`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestReview` (`[PullRequestReview](/en/graphql/reference/pulls#object-pullrequestreview)`) |

The deleted pull request review.  |

### [deletePullRequestReviewComment](#mutation-deletepullrequestreviewcomment)

Mutation

Deletes a pull request review comment.

#### Input fields for `deletePullRequestReviewComment`

- `input` (`[DeletePullRequestReviewCommentInput!](/en/graphql/reference/pulls#input-object-deletepullrequestreviewcommentinput)`)

#### Return fields for `deletePullRequestReviewComment`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestReview` (`[PullRequestReview](/en/graphql/reference/pulls#object-pullrequestreview)`) |

The pull request review the deleted comment belonged to.  |

|

`pullRequestReviewComment` (`[PullRequestReviewComment](/en/graphql/reference/pulls#object-pullrequestreviewcomment)`) |

The deleted pull request review comment.  |

### [dequeuePullRequest](#mutation-dequeuepullrequest)

Mutation

Remove a pull request from the merge queue.

#### Input fields for `dequeuePullRequest`

- `input` (`[DequeuePullRequestInput!](/en/graphql/reference/pulls#input-object-dequeuepullrequestinput)`)

#### Return fields for `dequeuePullRequest`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`mergeQueueEntry` (`[MergeQueueEntry](/en/graphql/reference/pulls#object-mergequeueentry)`) |

The merge queue entry of the dequeued pull request.  |

### [disablePullRequestAutoMerge](#mutation-disablepullrequestautomerge)

Mutation

Disable auto merge on the given pull request.

#### Input fields for `disablePullRequestAutoMerge`

- `input` (`[DisablePullRequestAutoMergeInput!](/en/graphql/reference/pulls#input-object-disablepullrequestautomergeinput)`)

#### Return fields for `disablePullRequestAutoMerge`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request auto merge was disabled on.  |

### [dismissPullRequestReview](#mutation-dismisspullrequestreview)

Mutation

Dismisses an approved or rejected pull request review.

#### Input fields for `dismissPullRequestReview`

- `input` (`[DismissPullRequestReviewInput!](/en/graphql/reference/pulls#input-object-dismisspullrequestreviewinput)`)

#### Return fields for `dismissPullRequestReview`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestReview` (`[PullRequestReview](/en/graphql/reference/pulls#object-pullrequestreview)`) |

The dismissed pull request review.  |

### [enablePullRequestAutoMerge](#mutation-enablepullrequestautomerge)

Mutation

Enable the default auto-merge on a pull request.

#### Input fields for `enablePullRequestAutoMerge`

- `input` (`[EnablePullRequestAutoMergeInput!](/en/graphql/reference/pulls#input-object-enablepullrequestautomergeinput)`)

#### Return fields for `enablePullRequestAutoMerge`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request auto-merge was enabled on.  |

### [enqueuePullRequest](#mutation-enqueuepullrequest)

Mutation

Add a pull request to the merge queue.

#### Input fields for `enqueuePullRequest`

- `input` (`[EnqueuePullRequestInput!](/en/graphql/reference/pulls#input-object-enqueuepullrequestinput)`)

#### Return fields for `enqueuePullRequest`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`mergeQueueEntry` (`[MergeQueueEntry](/en/graphql/reference/pulls#object-mergequeueentry)`) |

The merge queue entry for the enqueued pull request.  |

### [markFileAsViewed](#mutation-markfileasviewed)

Mutation

Mark a pull request file as viewed.

#### Input fields for `markFileAsViewed`

- `input` (`[MarkFileAsViewedInput!](/en/graphql/reference/pulls#input-object-markfileasviewedinput)`)

#### Return fields for `markFileAsViewed`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The updated pull request.  |

### [markPullRequestReadyForReview](#mutation-markpullrequestreadyforreview)

Mutation

Marks a pull request ready for review.

#### Input fields for `markPullRequestReadyForReview`

- `input` (`[MarkPullRequestReadyForReviewInput!](/en/graphql/reference/pulls#input-object-markpullrequestreadyforreviewinput)`)

#### Return fields for `markPullRequestReadyForReview`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request that is ready for review.  |

### [mergePullRequest](#mutation-mergepullrequest)

Mutation

Merge a pull request.

#### Input fields for `mergePullRequest`

- `input` (`[MergePullRequestInput!](/en/graphql/reference/pulls#input-object-mergepullrequestinput)`)

#### Return fields for `mergePullRequest`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request that was merged.  |

### [removePullRequestCreationCapBypassUsers](#mutation-removepullrequestcreationcapbypassusers)

Mutation

Remove users from the pull request creation cap bypass list. Only repository admins can manage the bypass list.

#### Input fields for `removePullRequestCreationCapBypassUsers`

- `input` (`[RemovePullRequestCreationCapBypassUsersInput!](/en/graphql/reference/pulls#input-object-removepullrequestcreationcapbypassusersinput)`)

#### Return fields for `removePullRequestCreationCapBypassUsers`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`repository` (`[Repository](/en/graphql/reference/repos#object-repository)`) |

The repository with the updated bypass list.  |

### [reopenPullRequest](#mutation-reopenpullrequest)

Mutation

Reopen a pull request.

#### Input fields for `reopenPullRequest`

- `input` (`[ReopenPullRequestInput!](/en/graphql/reference/pulls#input-object-reopenpullrequestinput)`)

#### Return fields for `reopenPullRequest`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request that was reopened.  |

### [requestReviews](#mutation-requestreviews)

Mutation

Set review requests on a pull request.

#### Input fields for `requestReviews`

- `input` (`[RequestReviewsInput!](/en/graphql/reference/pulls#input-object-requestreviewsinput)`)

#### Return fields for `requestReviews`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request that is getting requests.  |

|

`requestedReviewersEdge` (`[UserEdge](/en/graphql/reference/users#object-useredge)`) |

The edge from the pull request to the requested reviewers.  |

### [requestReviewsByLogin](#mutation-requestreviewsbylogin)

Mutation

Set review requests on a pull request using login strings instead of IDs.

#### Input fields for `requestReviewsByLogin`

- `input` (`[RequestReviewsByLoginInput!](/en/graphql/reference/pulls#input-object-requestreviewsbylogininput)`)

#### Return fields for `requestReviewsByLogin`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request that is getting requests.  |

|

`requestedReviewersEdge` (`[UserEdge](/en/graphql/reference/users#object-useredge)`) |

The edge from the pull request to the requested reviewers.  |

### [resolveReviewThread](#mutation-resolvereviewthread)

Mutation

Marks a review thread as resolved.

#### Input fields for `resolveReviewThread`

- `input` (`[ResolveReviewThreadInput!](/en/graphql/reference/pulls#input-object-resolvereviewthreadinput)`)

#### Return fields for `resolveReviewThread`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`thread` (`[PullRequestReviewThread](/en/graphql/reference/pulls#object-pullrequestreviewthread)`) |

The thread to resolve.  |

### [revertPullRequest](#mutation-revertpullrequest)

Mutation

Create a pull request that reverts the changes from a merged pull request.

#### Input fields for `revertPullRequest`

- `input` (`[RevertPullRequestInput!](/en/graphql/reference/pulls#input-object-revertpullrequestinput)`)

#### Return fields for `revertPullRequest`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request that was reverted.  |

|

`revertPullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The new pull request that reverts the input pull request.  |

### [submitPullRequestReview](#mutation-submitpullrequestreview)

Mutation

Submits a pending pull request review.

#### Input fields for `submitPullRequestReview`

- `input` (`[SubmitPullRequestReviewInput!](/en/graphql/reference/pulls#input-object-submitpullrequestreviewinput)`)

#### Return fields for `submitPullRequestReview`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestReview` (`[PullRequestReview](/en/graphql/reference/pulls#object-pullrequestreview)`) |

The submitted pull request review.  |

### [unarchivePullRequest](#mutation-unarchivepullrequest)

Mutation

Unarchive a pull request. Removes the archived flag from the pull request. Does not automatically reopen or unlock the pull request. Only repository admins can unarchive pull requests.

#### Input fields for `unarchivePullRequest`

- `input` (`[UnarchivePullRequestInput!](/en/graphql/reference/pulls#input-object-unarchivepullrequestinput)`)

#### Return fields for `unarchivePullRequest`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request that was unarchived.  |

### [unmarkFileAsViewed](#mutation-unmarkfileasviewed)

Mutation

Unmark a pull request file as viewed.

#### Input fields for `unmarkFileAsViewed`

- `input` (`[UnmarkFileAsViewedInput!](/en/graphql/reference/pulls#input-object-unmarkfileasviewedinput)`)

#### Return fields for `unmarkFileAsViewed`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The updated pull request.  |

### [unresolveReviewThread](#mutation-unresolvereviewthread)

Mutation

Marks a review thread as unresolved.

#### Input fields for `unresolveReviewThread`

- `input` (`[UnresolveReviewThreadInput!](/en/graphql/reference/pulls#input-object-unresolvereviewthreadinput)`)

#### Return fields for `unresolveReviewThread`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`thread` (`[PullRequestReviewThread](/en/graphql/reference/pulls#object-pullrequestreviewthread)`) |

The thread to resolve.  |

### [updatePullRequest](#mutation-updatepullrequest)

Mutation

Update a pull request.

#### Input fields for `updatePullRequest`

- `input` (`[UpdatePullRequestInput!](/en/graphql/reference/pulls#input-object-updatepullrequestinput)`)

#### Return fields for `updatePullRequest`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The updated pull request.  |

### [updatePullRequestBranch](#mutation-updatepullrequestbranch)

Mutation

Merge or Rebase HEAD from upstream branch into pull request branch.

#### Input fields for `updatePullRequestBranch`

- `input` (`[UpdatePullRequestBranchInput!](/en/graphql/reference/pulls#input-object-updatepullrequestbranchinput)`)

#### Return fields for `updatePullRequestBranch`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The updated pull request.  |

### [updatePullRequestReview](#mutation-updatepullrequestreview)

Mutation

Updates the body of a pull request review.

#### Input fields for `updatePullRequestReview`

- `input` (`[UpdatePullRequestReviewInput!](/en/graphql/reference/pulls#input-object-updatepullrequestreviewinput)`)

#### Return fields for `updatePullRequestReview`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestReview` (`[PullRequestReview](/en/graphql/reference/pulls#object-pullrequestreview)`) |

The updated pull request review.  |

### [updatePullRequestReviewComment](#mutation-updatepullrequestreviewcomment)

Mutation

Updates a pull request review comment.

#### Input fields for `updatePullRequestReviewComment`

- `input` (`[UpdatePullRequestReviewCommentInput!](/en/graphql/reference/pulls#input-object-updatepullrequestreviewcommentinput)`)

#### Return fields for `updatePullRequestReviewComment`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestReviewComment` (`[PullRequestReviewComment](/en/graphql/reference/pulls#object-pullrequestreviewcomment)`) |

The updated comment.  |

### [updateTeamReviewAssignment](#mutation-updateteamreviewassignment)

Mutation

Updates team review assignment.

#### Input fields for `updateTeamReviewAssignment`

- `input` (`[UpdateTeamReviewAssignmentInput!](/en/graphql/reference/pulls#input-object-updateteamreviewassignmentinput)`)

#### Return fields for `updateTeamReviewAssignment`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`team` (`[Team](/en/graphql/reference/teams#object-team)`) |

The team that was modified.  |

## [Objects](#objects)

### [AddedToMergeQueueEvent](#object-addedtomergequeueevent)

Object

Represents an`added_to_merge_queue`event on a given pull request.

#### `AddedToMergeQueueEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `AddedToMergeQueueEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`enqueuer` (`[User](/en/graphql/reference/users#object-user)`) |

The user who added this Pull Request to the merge queue.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the AddedToMergeQueueEvent object.  |

|

`mergeQueue` (`[MergeQueue](/en/graphql/reference/pulls#object-mergequeue)`) |

The merge queue where this pull request was added to.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

### [AutomaticBaseChangeFailedEvent](#object-automaticbasechangefailedevent)

Object

Represents a`automatic_base_change_failed`event on a given pull request.

#### `AutomaticBaseChangeFailedEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `AutomaticBaseChangeFailedEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the AutomaticBaseChangeFailedEvent object.  |

|

`newBase` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The new base for this PR.  |

|

`oldBase` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The old base for this PR.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

### [AutomaticBaseChangeSucceededEvent](#object-automaticbasechangesucceededevent)

Object

Represents a`automatic_base_change_succeeded`event on a given pull request.

#### `AutomaticBaseChangeSucceededEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `AutomaticBaseChangeSucceededEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the AutomaticBaseChangeSucceededEvent object.  |

|

`newBase` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The new base for this PR.  |

|

`oldBase` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The old base for this PR.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

### [AutoMergeDisabledEvent](#object-automergedisabledevent)

Object

Represents a`auto_merge_disabled`event on a given pull request.

#### `AutoMergeDisabledEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `AutoMergeDisabledEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`disabler` (`[User](/en/graphql/reference/users#object-user)`) |

The user who disabled auto-merge for this Pull Request.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the AutoMergeDisabledEvent object.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

|

`reason` (`[String](/en/graphql/reference/other#scalar-string)`) |

The reason auto-merge was disabled.  |

|

`reasonCode` (`[String](/en/graphql/reference/other#scalar-string)`) |

The reason_code relating to why auto-merge was disabled.  |

### [AutoMergeEnabledEvent](#object-automergeenabledevent)

Object

Represents a`auto_merge_enabled`event on a given pull request.

#### `AutoMergeEnabledEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `AutoMergeEnabledEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`enabler` (`[User](/en/graphql/reference/users#object-user)`) |

The user who enabled auto-merge for this Pull Request.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the AutoMergeEnabledEvent object.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

### [AutoMergeRequest](#object-automergerequest)

Object

Represents an auto-merge request for a pull request.

#### Fields for `AutoMergeRequest`

| Name | Description  |

|

`authorEmail` (`[String](/en/graphql/reference/other#scalar-string)`) |

The email address of the author of this auto-merge request.  |

|

`commitBody` (`[String](/en/graphql/reference/other#scalar-string)`) |

The commit message of the auto-merge request. If a merge queue is required by the base branch, this value will be set by the merge queue when merging.  |

|

`commitHeadline` (`[String](/en/graphql/reference/other#scalar-string)`) |

The commit title of the auto-merge request. If a merge queue is required by the base branch, this value will be set by the merge queue when merging.  |

|

`enabledAt` (`[DateTime](/en/graphql/reference/other#scalar-datetime)`) |

When was this auto-merge request was enabled.  |

|

`enabledBy` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

The actor who created the auto-merge request.  |

|

`mergeMethod` (`[PullRequestMergeMethod!](/en/graphql/reference/pulls#enum-pullrequestmergemethod)`) |

The merge method of the auto-merge request. If a merge queue is required by the base branch, this value will be set by the merge queue when merging.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request that this auto-merge request is set against.  |

### [AutoRebaseEnabledEvent](#object-autorebaseenabledevent)

Object

Represents a`auto_rebase_enabled`event on a given pull request.

#### `AutoRebaseEnabledEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `AutoRebaseEnabledEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`enabler` (`[User](/en/graphql/reference/users#object-user)`) |

The user who enabled auto-merge (rebase) for this Pull Request.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the AutoRebaseEnabledEvent object.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

### [AutoSquashEnabledEvent](#object-autosquashenabledevent)

Object

Represents a`auto_squash_enabled`event on a given pull request.

#### `AutoSquashEnabledEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `AutoSquashEnabledEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`enabler` (`[User](/en/graphql/reference/users#object-user)`) |

The user who enabled auto-merge (squash) for this Pull Request.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the AutoSquashEnabledEvent object.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

### [BaseRefChangedEvent](#object-baserefchangedevent)

Object

Represents a`base_ref_changed`event on a given issue or pull request.

#### `BaseRefChangedEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `BaseRefChangedEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`currentRefName` (`[String!](/en/graphql/reference/other#scalar-string)`) |

Identifies the name of the base ref for the pull request after it was changed.  |

|

`databaseId` (`[Int](/en/graphql/reference/other#scalar-int)`) |

Identifies the primary key from the database.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the BaseRefChangedEvent object.  |

|

`previousRefName` (`[String!](/en/graphql/reference/other#scalar-string)`) |

Identifies the name of the base ref for the pull request before it was changed.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

### [BaseRefDeletedEvent](#object-baserefdeletedevent)

Object

Represents a`base_ref_deleted`event on a given pull request.

#### `BaseRefDeletedEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `BaseRefDeletedEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`baseRefName` (`[String](/en/graphql/reference/other#scalar-string)`) |

Identifies the name of the Ref associated with the `base_ref_deleted` event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the BaseRefDeletedEvent object.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

### [BaseRefForcePushedEvent](#object-baserefforcepushedevent)

Object

Represents a`base_ref_force_pushed`event on a given pull request.

#### `BaseRefForcePushedEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `BaseRefForcePushedEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`afterCommit` (`[Commit](/en/graphql/reference/commits#object-commit)`) |

Identifies the after commit SHA for the`base_ref_force_pushed`event.  |

|

`beforeCommit` (`[Commit](/en/graphql/reference/commits#object-commit)`) |

Identifies the before commit SHA for the`base_ref_force_pushed`event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the BaseRefForcePushedEvent object.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

|

`ref` (`[Ref](/en/graphql/reference/git#object-ref)`) |

Identifies the fully qualified ref name for the`base_ref_force_pushed`event.  |

### [ConvertedFromDraftEvent](#object-convertedfromdraftevent)

Object

Represents a`converted_from_draft`event on a given issue or pull request.

#### `ConvertedFromDraftEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`
- `[ProjectV2Event](/en/graphql/reference/projects#interface-projectv2event)`

#### Fields for `ConvertedFromDraftEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the ConvertedFromDraftEvent object.  |

|

`project` (`[ProjectV2](/en/graphql/reference/projects#object-projectv2)`) |

Project referenced by event.  |

|

`wasAutomated` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Did this event result from workflow automation?.  |

### [ConvertToDraftEvent](#object-converttodraftevent)

Object

Represents a`convert_to_draft`event on a given pull request.

#### `ConvertToDraftEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`
- `[UniformResourceLocatable](/en/graphql/reference/meta#interface-uniformresourcelocatable)`

#### Fields for `ConvertToDraftEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the ConvertToDraftEvent object.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

|

`resourcePath` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP path for this convert to draft event.  |

|

`url` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP URL for this convert to draft event.  |

### [CopilotCodeReviewParameters](#object-copilotcodereviewparameters)

Object

Request Copilot code review for new pull requests automatically if the author has access to Copilot code review and their premium requests quota has not reached the limit.

#### Fields for `CopilotCodeReviewParameters`

| Name | Description  |

|

`reviewDraftPullRequests` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Copilot automatically reviews draft pull requests before they are marked as ready for review.  |

|

`reviewOnPush` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Copilot automatically reviews each new push to the pull request.  |

### [HeadRefDeletedEvent](#object-headrefdeletedevent)

Object

Represents a`head_ref_deleted`event on a given pull request.

#### `HeadRefDeletedEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `HeadRefDeletedEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`headRef` (`[Ref](/en/graphql/reference/git#object-ref)`) |

Identifies the Ref associated with the `head_ref_deleted` event.  |

|

`headRefName` (`[String!](/en/graphql/reference/other#scalar-string)`) |

Identifies the name of the Ref associated with the `head_ref_deleted` event.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the HeadRefDeletedEvent object.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

### [HeadRefForcePushedEvent](#object-headrefforcepushedevent)

Object

Represents a`head_ref_force_pushed`event on a given pull request.

#### `HeadRefForcePushedEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `HeadRefForcePushedEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`afterCommit` (`[Commit](/en/graphql/reference/commits#object-commit)`) |

Identifies the after commit SHA for the`head_ref_force_pushed`event.  |

|

`beforeCommit` (`[Commit](/en/graphql/reference/commits#object-commit)`) |

Identifies the before commit SHA for the`head_ref_force_pushed`event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the HeadRefForcePushedEvent object.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

|

`ref` (`[Ref](/en/graphql/reference/git#object-ref)`) |

Identifies the fully qualified ref name for the`head_ref_force_pushed`event.  |

### [HeadRefRestoredEvent](#object-headrefrestoredevent)

Object

Represents a`head_ref_restored`event on a given pull request.

#### `HeadRefRestoredEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `HeadRefRestoredEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the HeadRefRestoredEvent object.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

### [MergedEvent](#object-mergedevent)

Object

Represents a`merged`event on a given pull request.

#### `MergedEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`
- `[UniformResourceLocatable](/en/graphql/reference/meta#interface-uniformresourcelocatable)`

#### Fields for `MergedEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`commit` (`[Commit](/en/graphql/reference/commits#object-commit)`) |

Identifies the commit associated with the `merge` event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the MergedEvent object.  |

|

`mergeRef` (`[Ref](/en/graphql/reference/git#object-ref)`) |

Identifies the Ref associated with the `merge` event.  |

|

`mergeRefName` (`[String!](/en/graphql/reference/other#scalar-string)`) |

Identifies the name of the Ref associated with the `merge` event.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

|

`resourcePath` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP path for this merged event.  |

|

`url` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP URL for this merged event.  |

### [MergeQueue](#object-mergequeue)

Object

The queue of pull request entries to be merged into a protected branch in a repository.

#### `MergeQueue` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `MergeQueue`

| Name | Description  |

|

`configuration` (`[MergeQueueConfiguration](/en/graphql/reference/pulls#object-mergequeueconfiguration)`) |

The configuration for this merge queue.  |

|

`entries` (`[MergeQueueEntryConnection](/en/graphql/reference/pulls#object-mergequeueentryconnection)`) |

The entries in the queue.

Arguments for `entries`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the MergeQueue object.  |

|

`nextEntryEstimatedTimeToMerge` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The estimated time in seconds until a newly added entry would be merged.  |

|

`repository` (`[Repository](/en/graphql/reference/repos#object-repository)`) |

The repository this merge queue belongs to.  |

|

`resourcePath` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP path for this merge queue.  |

|

`url` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP URL for this merge queue.  |

### [MergeQueueConfiguration](#object-mergequeueconfiguration)

Object

Configuration for a MergeQueue.

#### Fields for `MergeQueueConfiguration`

| Name | Description  |

|

`checkResponseTimeout` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The amount of time in minutes to wait for a check response before considering it a failure.  |

|

`maximumEntriesToBuild` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The maximum number of entries to build at once.  |

|

`maximumEntriesToMerge` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The maximum number of entries to merge at once.  |

|

`mergeMethod` (`[PullRequestMergeMethod](/en/graphql/reference/pulls#enum-pullrequestmergemethod)`) |

The merge method to use for this queue.  |

|

`mergingStrategy` (`[MergeQueueMergingStrategy](/en/graphql/reference/pulls#enum-mergequeuemergingstrategy)`) |

The strategy to use when merging entries.  |

|

`minimumEntriesToMerge` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The minimum number of entries required to merge at once.  |

|

`minimumEntriesToMergeWaitTime` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The amount of time in minutes to wait before ignoring the minumum number of entries in the queue requirement and merging a collection of entries.  |

### [MergeQueueEntry](#object-mergequeueentry)

Object

Entries in a MergeQueue.

#### `MergeQueueEntry` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `MergeQueueEntry`

| Name | Description  |

|

`baseCommit` (`[Commit](/en/graphql/reference/commits#object-commit)`) |

The base commit for this entry.  |

|

`enqueuedAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

The date and time this entry was added to the merge queue.  |

|

`enqueuer` (`[Actor!](/en/graphql/reference/users#interface-actor)`) |

The actor that enqueued this entry.  |

|

`estimatedTimeToMerge` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The estimated time in seconds until this entry will be merged.  |

|

`headCommit` (`[Commit](/en/graphql/reference/commits#object-commit)`) |

The head commit for this entry.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the MergeQueueEntry object.  |

|

`jump` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether this pull request should jump the queue.  |

|

`mergeQueue` (`[MergeQueue](/en/graphql/reference/pulls#object-mergequeue)`) |

The merge queue that this entry belongs to.  |

|

`position` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

The position of this entry in the queue.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request that will be added to a merge group.  |

|

`solo` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Does this pull request need to be deployed on its own.  |

|

`state` (`[MergeQueueEntryState!](/en/graphql/reference/pulls#enum-mergequeueentrystate)`) |

The state of this entry in the queue.  |

### [MergeQueueEntryConnection](#object-mergequeueentryconnection)

Object

The connection type for MergeQueueEntry.

#### Fields for `MergeQueueEntryConnection`

| Name | Description  |

|

`edges` (`[[MergeQueueEntryEdge]](/en/graphql/reference/pulls#object-mergequeueentryedge)`) |

A list of edges.  |

|

`nodes` (`[[MergeQueueEntry]](/en/graphql/reference/pulls#object-mergequeueentry)`) |

A list of nodes.  |

|

`pageInfo` (`[PageInfo!](/en/graphql/reference/other#object-pageinfo)`) |

Information to aid in pagination.  |

|

`totalCount` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Identifies the total count of items in the connection.  |

### [MergeQueueEntryEdge](#object-mergequeueentryedge)

Object

An edge in a connection.

#### Fields for `MergeQueueEntryEdge`

| Name | Description  |

|

`cursor` (`[String!](/en/graphql/reference/other#scalar-string)`) |

A cursor for use in pagination.  |

|

`node` (`[MergeQueueEntry](/en/graphql/reference/pulls#object-mergequeueentry)`) |

The item at the end of the edge.  |

### [MergeQueueParameters](#object-mergequeueparameters)

Object

Merges must be performed via a merge queue.

#### Fields for `MergeQueueParameters`

| Name | Description  |

|

`checkResponseTimeoutMinutes` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Maximum time for a required status check to report a conclusion. After this much time has elapsed, checks that have not reported a conclusion will be assumed to have failed.  |

|

`groupingStrategy` (`[MergeQueueGroupingStrategy!](/en/graphql/reference/pulls#enum-mergequeuegroupingstrategy)`) |

When set to ALLGREEN, the merge commit created by merge queue for each PR in the group must pass all required checks to merge. When set to HEADGREEN, only the commit at the head of the merge group, i.e. the commit containing changes from all of the PRs in the group, must pass its required checks to merge.  |

|

`maxEntriesToBuild` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Limit the number of queued pull requests requesting checks and workflow runs at the same time.  |

|

`maxEntriesToMerge` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

The maximum number of PRs that will be merged together in a group.  |

|

`mergeMethod` (`[MergeQueueMergeMethod!](/en/graphql/reference/pulls#enum-mergequeuemergemethod)`) |

Method to use when merging changes from queued pull requests.  |

|

`minEntriesToMerge` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

The minimum number of PRs that will be merged together in a group.  |

|

`minEntriesToMergeWaitMinutes` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

The time merge queue should wait after the first PR is added to the queue for the minimum group size to be met. After this time has elapsed, the minimum group size will be ignored and a smaller group will be merged.  |

### [PullRequest](#object-pullrequest)

Object

A repository pull request.

#### `PullRequest` Implements

- `[Assignable](/en/graphql/reference/issues#interface-assignable)`
- `[Closable](/en/graphql/reference/issues#interface-closable)`
- `[Comment](/en/graphql/reference/issues#interface-comment)`
- `[Labelable](/en/graphql/reference/issues#interface-labelable)`
- `[Lockable](/en/graphql/reference/issues#interface-lockable)`
- `[Node](/en/graphql/reference/meta#interface-node)`
- `[ProjectV2Owner](/en/graphql/reference/projects#interface-projectv2owner)`
- `[Reactable](/en/graphql/reference/reactions#interface-reactable)`
- `[RepositoryNode](/en/graphql/reference/repos#interface-repositorynode)`
- `[Subscribable](/en/graphql/reference/activity#interface-subscribable)`
- `[UniformResourceLocatable](/en/graphql/reference/meta#interface-uniformresourcelocatable)`
- `[Updatable](/en/graphql/reference/issues#interface-updatable)`
- `[UpdatableComment](/en/graphql/reference/issues#interface-updatablecomment)`

#### Fields for `PullRequest`

| Name | Description  |

|

`activeLockReason` (`[LockReason](/en/graphql/reference/issues#enum-lockreason)`) |

Reason that the conversation was locked.  |

|

`additions` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

The number of additions in this pull request.  |

|

`assignedActors` (`[AssigneeConnection!](/en/graphql/reference/issues#object-assigneeconnection)`) |

A list of actors assigned to this object.

Arguments for `assignedActors`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`assignees` (`[UserConnection!](/en/graphql/reference/users#object-userconnection)`) |

A list of Users assigned to this object.

Arguments for `assignees`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`author` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

The actor who authored the comment.  |

|

`authorAssociation` (`[CommentAuthorAssociation!](/en/graphql/reference/issues#enum-commentauthorassociation)`) |

Author's association with the subject of the comment.  |

|

`autoMergeRequest` (`[AutoMergeRequest](/en/graphql/reference/pulls#object-automergerequest)`) |

Returns the auto-merge request object if one exists for this pull request.  |

|

`baseRef` (`[Ref](/en/graphql/reference/git#object-ref)`) |

Identifies the base Ref associated with the pull request.  |

|

`baseRefName` (`[String!](/en/graphql/reference/other#scalar-string)`) |

Identifies the name of the base Ref associated with the pull request, even if the ref has been deleted.  |

|

`baseRefOid` (`[GitObjectID!](/en/graphql/reference/other#scalar-gitobjectid)`) |

Identifies the oid of the base ref associated with the pull request, even if the ref has been deleted.  |

|

`baseRepository` (`[Repository](/en/graphql/reference/repos#object-repository)`) |

The repository associated with this pull request's base Ref.  |

|

`body` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The body as Markdown.  |

|

`bodyHTML` (`[HTML!](/en/graphql/reference/other#scalar-html)`) |

The body rendered to HTML.  |

|

`bodyText` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The body rendered to text.  |

|

`canBeRebased` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether or not the pull request is rebaseable.  |

|

`changedFiles` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

The number of changed files in this pull request.  |

|

`checksResourcePath` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP path for the checks of this pull request.  |

|

`checksUrl` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP URL for the checks of this pull request.  |

|

`closed` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

`true` if the pull request is closed.  |

|

`closedAt` (`[DateTime](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was closed.  |

|

`closingIssuesReferences` (`[IssueConnection](/en/graphql/reference/issues#object-issueconnection)`) |

List of issues that may be closed by this pull request.

Arguments for `closingIssuesReferences`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`orderBy` (`[IssueOrder](/en/graphql/reference/issues#input-object-issueorder)`)

Ordering options for issues returned from the connection.

-

`userLinkedOnly` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`)

Return only manually linked Issues.

The default value is `false`.  |

|

`comments` (`[IssueCommentConnection!](/en/graphql/reference/issues#object-issuecommentconnection)`) |

A list of comments associated with the pull request.

Arguments for `comments`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`orderBy` (`[IssueCommentOrder](/en/graphql/reference/issues#input-object-issuecommentorder)`)

Ordering options for issue comments returned from the connection.  |

|

`commits` (`[PullRequestCommitConnection!](/en/graphql/reference/pulls#object-pullrequestcommitconnection)`) |

A list of commits present in this pull request's head branch not present in the base branch.

Arguments for `commits`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`createdViaEmail` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if this comment was created via an email reply.  |

|

`databaseId` (`[Int](/en/graphql/reference/other#scalar-int)`) |

Identifies the primary key from the database.

Warning

`databaseId` is deprecated.

`databaseId` will be removed because it does not support 64-bit signed integer identifiers. Use `fullDatabaseId` instead. Removal on 2024-07-01 UTC.  |

|

`deletions` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

The number of deletions in this pull request.  |

|

`editor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

The actor who edited this pull request's body.  |

|

`files` (`[PullRequestChangedFileConnection](/en/graphql/reference/pulls#object-pullrequestchangedfileconnection)`) |

Lists the files changed within this pull request.

Arguments for `files`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`fullDatabaseId` (`[BigInt](/en/graphql/reference/other#scalar-bigint)`) |

Identifies the primary key from the database as a BigInt.  |

|

`headRef` (`[Ref](/en/graphql/reference/git#object-ref)`) |

Identifies the head Ref associated with the pull request.  |

|

`headRefName` (`[String!](/en/graphql/reference/other#scalar-string)`) |

Identifies the name of the head Ref associated with the pull request, even if the ref has been deleted.  |

|

`headRefOid` (`[GitObjectID!](/en/graphql/reference/other#scalar-gitobjectid)`) |

Identifies the oid of the head ref associated with the pull request, even if the ref has been deleted.  |

|

`headRepository` (`[Repository](/en/graphql/reference/repos#object-repository)`) |

The repository associated with this pull request's head Ref.  |

|

`headRepositoryOwner` (`[RepositoryOwner](/en/graphql/reference/repos#interface-repositoryowner)`) |

The owner of the repository associated with this pull request's head Ref.  |

|

`hovercard` (`[Hovercard!](/en/graphql/reference/users#object-hovercard)`) |

The hovercard information for this issue.

Arguments for `hovercard`

-

`includeNotificationContexts` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`)

Whether or not to include notification contexts.

The default value is `true`.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the PullRequest object.  |

|

`includesCreatedEdit` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if this comment was edited and includes an edit with the creation data.  |

|

`isCrossRepository` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

The head and base repositories are different.  |

|

`isDraft` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Identifies if the pull request is a draft.  |

|

`isInMergeQueue` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Indicates whether the pull request is in a merge queue.  |

|

`isMergeQueueEnabled` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Indicates whether the pull request's base ref has a merge queue enabled.  |

|

`isReadByViewer` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`) |

Is this pull request read by the viewer.  |

|

`labels` (`[LabelConnection](/en/graphql/reference/issues#object-labelconnection)`) |

A list of labels associated with the object.

Arguments for `labels`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`orderBy` (`[LabelOrder](/en/graphql/reference/issues#input-object-labelorder)`)

Ordering options for labels returned from the connection.  |

|

`lastEditedAt` (`[DateTime](/en/graphql/reference/other#scalar-datetime)`) |

The moment the editor made the last edit.  |

|

`latestOpinionatedReviews` (`[PullRequestReviewConnection](/en/graphql/reference/pulls#object-pullrequestreviewconnection)`) |

A list of latest reviews per user associated with the pull request.

Arguments for `latestOpinionatedReviews`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`writersOnly` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`)

Only return reviews from user who have write access to the repository.

The default value is `false`.  |

|

`latestReviews` (`[PullRequestReviewConnection](/en/graphql/reference/pulls#object-pullrequestreviewconnection)`) |

A list of latest reviews per user associated with the pull request that are not also pending review.

Arguments for `latestReviews`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`locked` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

`true` if the pull request is locked.  |

|

`maintainerCanModify` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Indicates whether maintainers can modify the pull request.  |

|

`mergeCommit` (`[Commit](/en/graphql/reference/commits#object-commit)`) |

The commit that was created when this pull request was merged.  |

|

`mergeQueue` (`[MergeQueue](/en/graphql/reference/pulls#object-mergequeue)`) |

The merge queue for the pull request's base branch.  |

|

`mergeQueueEntry` (`[MergeQueueEntry](/en/graphql/reference/pulls#object-mergequeueentry)`) |

The merge queue entry of the pull request in the base branch's merge queue.  |

|

`mergeStateStatus` (`[MergeStateStatus!](/en/graphql/reference/pulls#enum-mergestatestatus)`) |

Detailed information about the current pull request merge state status.  |

|

`mergeable` (`[MergeableState!](/en/graphql/reference/pulls#enum-mergeablestate)`) |

Whether or not the pull request can be merged based on the existence of merge conflicts.  |

|

`merged` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether or not the pull request was merged.  |

|

`mergedAt` (`[DateTime](/en/graphql/reference/other#scalar-datetime)`) |

The date and time that the pull request was merged.  |

|

`mergedBy` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

The actor who merged the pull request.  |

|

`milestone` (`[Milestone](/en/graphql/reference/issues#object-milestone)`) |

Identifies the milestone associated with the pull request.  |

|

`number` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Identifies the pull request number.  |

|

`participants` (`[UserConnection!](/en/graphql/reference/users#object-userconnection)`) |

A list of Users that are participating in the Pull Request conversation.

Arguments for `participants`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`permalink` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The permalink to the pull request.  |

|

`potentialMergeCommit` (`[Commit](/en/graphql/reference/commits#object-commit)`) |

The commit that GitHub automatically generated to test if this pull request could be merged. This field will not return a value if the pull request is merged, or if the test merge commit is still being generated. See the `mergeable` field for more details on the mergeability of the pull request.  |

|

`projectCards` (`[ProjectCardConnection!](/en/graphql/reference/projects-classic#object-projectcardconnection)`) |

List of project cards associated with this pull request.

Warning

`projectCards` is deprecated.

Projects (classic) is being deprecated in favor of the new Projects experience, see: [https://github.blog/changelog/2024-05-23-sunset-notice-projects-classic/](https://github.blog/changelog/2024-05-23-sunset-notice-projects-classic/). Removal on 2025-04-01 UTC.

Arguments for `projectCards`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`archivedStates` (`[[ProjectCardArchivedState]](/en/graphql/reference/projects-classic#enum-projectcardarchivedstate)`)

A list of archived states to filter the cards by.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`projectItems` (`[ProjectV2ItemConnection](/en/graphql/reference/projects#object-projectv2itemconnection)`) |

List of project items associated with this pull request.

Arguments for `projectItems`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`includeArchived` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`)

Include archived items.

The default value is `true`.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`projectV2` (`[ProjectV2](/en/graphql/reference/projects#object-projectv2)`) |

Find a project by number.

Arguments for `projectV2`

-

`number` (`[Int!](/en/graphql/reference/other#scalar-int)`)

The project number.  |

|

`projectsV2` (`[ProjectV2Connection!](/en/graphql/reference/projects#object-projectv2connection)`) |

A list of projects under the owner.

Arguments for `projectsV2`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`minPermissionLevel` (`[ProjectV2PermissionLevel](/en/graphql/reference/projects#enum-projectv2permissionlevel)`)

Filter projects based on user role.

The default value is `READ`.

-

`orderBy` (`[ProjectV2Order](/en/graphql/reference/projects#input-object-projectv2order)`)

How to order the returned projects.

-

`query` (`[String](/en/graphql/reference/other#scalar-string)`)

A project to search for under the owner.  |

|

`publishedAt` (`[DateTime](/en/graphql/reference/other#scalar-datetime)`) |

Identifies when the comment was published at.  |

|

`reactionGroups` (`[[ReactionGroup!]](/en/graphql/reference/reactions#object-reactiongroup)`) |

A list of reactions grouped by content left on the subject.  |

|

`reactions` (`[ReactionConnection!](/en/graphql/reference/reactions#object-reactionconnection)`) |

A list of Reactions left on the Issue.

Arguments for `reactions`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`content` (`[ReactionContent](/en/graphql/reference/reactions#enum-reactioncontent)`)

Allows filtering Reactions by emoji.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`orderBy` (`[ReactionOrder](/en/graphql/reference/reactions#input-object-reactionorder)`)

Allows specifying the order in which reactions are returned.  |

|

`repository` (`[Repository!](/en/graphql/reference/repos#object-repository)`) |

The repository associated with this node.  |

|

`resourcePath` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP path for this pull request.  |

|

`revertResourcePath` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP path for reverting this pull request.  |

|

`revertUrl` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP URL for reverting this pull request.  |

|

`reviewDecision` (`[PullRequestReviewDecision](/en/graphql/reference/pulls#enum-pullrequestreviewdecision)`) |

The current status of this pull request with respect to code review.  |

|

`reviewRequests` (`[ReviewRequestConnection](/en/graphql/reference/pulls#object-reviewrequestconnection)`) |

A list of review requests associated with the pull request.

Arguments for `reviewRequests`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`reviewThreads` (`[PullRequestReviewThreadConnection!](/en/graphql/reference/pulls#object-pullrequestreviewthreadconnection)`) |

The list of all review threads for this pull request.

Arguments for `reviewThreads`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`reviews` (`[PullRequestReviewConnection](/en/graphql/reference/pulls#object-pullrequestreviewconnection)`) |

A list of reviews associated with the pull request.

Arguments for `reviews`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`author` (`[String](/en/graphql/reference/other#scalar-string)`)

Filter by author of the review.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`states` (`[[PullRequestReviewState!]](/en/graphql/reference/pulls#enum-pullrequestreviewstate)`)

A list of states to filter the reviews.  |

|

`state` (`[PullRequestState!](/en/graphql/reference/pulls#enum-pullrequeststate)`) |

Identifies the state of the pull request.  |

|

`statusCheckRollup` (`[StatusCheckRollup](/en/graphql/reference/commits#object-statuscheckrollup)`) |

Check and Status rollup information for the PR's head ref.  |

|

`suggestedActors` (`[AssigneeConnection!](/en/graphql/reference/issues#object-assigneeconnection)`) |

A list of suggested actors to assign to this object.

Arguments for `suggestedActors`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`query` (`[String](/en/graphql/reference/other#scalar-string)`)

If provided, searches users by login or profile name.  |

|

`suggestedReviewerActors` (`[SuggestedReviewerActorConnection!](/en/graphql/reference/pulls#object-suggestedrevieweractorconnection)`) |

Reviewer actor suggestions based on commit history, past review comments, and integrations.

Arguments for `suggestedReviewerActors`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`query` (`[String](/en/graphql/reference/other#scalar-string)`)

Search actors with query on user name and login.  |

|

`suggestedReviewers` (`[[SuggestedReviewer]!](/en/graphql/reference/pulls#object-suggestedreviewer)`) |

A list of reviewer suggestions based on commit history and past review comments.  |

|

`timeline` (`[PullRequestTimelineConnection!](/en/graphql/reference/pulls#object-pullrequesttimelineconnection)`) |

A list of events, comments, commits, etc. associated with the pull request.

Warning

`timeline` is deprecated.

`timeline` will be removed Use PullRequest.timelineItems instead. Removal on 2020-10-01 UTC.

Arguments for `timeline`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`since` (`[DateTime](/en/graphql/reference/other#scalar-datetime)`)

Allows filtering timeline events by a `since` timestamp.  |

|

`timelineItems` (`[PullRequestTimelineItemsConnection!](/en/graphql/reference/pulls#object-pullrequesttimelineitemsconnection)`) |

A list of events, comments, commits, etc. associated with the pull request.

Arguments for `timelineItems`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`itemTypes` (`[[PullRequestTimelineItemsItemType!]](/en/graphql/reference/other#enum-pullrequesttimelineitemsitemtype)`)

Filter timeline items by type.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`since` (`[DateTime](/en/graphql/reference/other#scalar-datetime)`)

Filter timeline items by a `since` timestamp.

-

`skip` (`[Int](/en/graphql/reference/other#scalar-int)`)

Skips the first n elements in the list.  |

|

`title` (`[String!](/en/graphql/reference/other#scalar-string)`) |

Identifies the pull request title.  |

|

`titleHTML` (`[HTML!](/en/graphql/reference/other#scalar-html)`) |

Identifies the pull request title rendered to HTML.  |

|

`totalCommentsCount` (`[Int](/en/graphql/reference/other#scalar-int)`) |

Returns a count of how many comments this pull request has received.  |

|

`updatedAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was last updated.  |

|

`url` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP URL for this pull request.  |

|

`userContentEdits` (`[UserContentEditConnection](/en/graphql/reference/users#object-usercontenteditconnection)`) |

A list of edits to this content.

Arguments for `userContentEdits`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`viewerCanApplySuggestion` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether or not the viewer can apply suggestion.  |

|

`viewerCanClose` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Indicates if the object can be closed by the viewer.  |

|

`viewerCanDeleteHeadRef` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if the viewer can restore the deleted head ref.  |

|

`viewerCanDisableAutoMerge` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether or not the viewer can disable auto-merge.  |

|

`viewerCanEditFiles` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Can the viewer edit files within this pull request.  |

|

`viewerCanEnableAutoMerge` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether or not the viewer can enable auto-merge.  |

|

`viewerCanLabel` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Indicates if the viewer can edit labels for this object.  |

|

`viewerCanMergeAsAdmin` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Indicates whether the viewer can bypass branch protections and merge the pull request immediately.  |

|

`viewerCanReact` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Can user react to this subject.  |

|

`viewerCanReopen` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Indicates if the object can be reopened by the viewer.  |

|

`viewerCanSubscribe` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if the viewer is able to change their subscription status for the repository.  |

|

`viewerCanUpdate` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if the current viewer can update this object.  |

|

`viewerCanUpdateBranch` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether or not the viewer can update the head ref of this PR, by merging or rebasing the base ref. If the head ref is up to date or unable to be updated by this user, this will return false.  |

|

`viewerCannotUpdateReasons` (`[[CommentCannotUpdateReason!]!](/en/graphql/reference/issues#enum-commentcannotupdatereason)`) |

Reasons why the current viewer can not update this comment.  |

|

`viewerDidAuthor` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Did the viewer author this comment.  |

|

`viewerLatestReview` (`[PullRequestReview](/en/graphql/reference/pulls#object-pullrequestreview)`) |

The latest review given from the viewer.  |

|

`viewerLatestReviewRequest` (`[ReviewRequest](/en/graphql/reference/pulls#object-reviewrequest)`) |

The person who has requested the viewer for review on this pull request.  |

|

`viewerMergeBodyText` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The merge body text for the viewer and method.

Arguments for `viewerMergeBodyText`

-

`mergeType` (`[PullRequestMergeMethod](/en/graphql/reference/pulls#enum-pullrequestmergemethod)`)

The merge method for the message.  |

|

`viewerMergeHeadlineText` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The merge headline text for the viewer and method.

Arguments for `viewerMergeHeadlineText`

-

`mergeType` (`[PullRequestMergeMethod](/en/graphql/reference/pulls#enum-pullrequestmergemethod)`)

The merge method for the message.  |

|

`viewerSubscription` (`[SubscriptionState](/en/graphql/reference/activity#enum-subscriptionstate)`) |

Identifies if the viewer is watching, not watching, or ignoring the subscribable entity.  |

### [PullRequestChangedFile](#object-pullrequestchangedfile)

Object

A file changed in a pull request.

#### Fields for `PullRequestChangedFile`

| Name | Description  |

|

`additions` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

The number of additions to the file.  |

|

`changeType` (`[PatchStatus!](/en/graphql/reference/pulls#enum-patchstatus)`) |

How the file was changed in this PullRequest.  |

|

`deletions` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

The number of deletions to the file.  |

|

`path` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The path of the file.  |

|

`viewerViewedState` (`[FileViewedState!](/en/graphql/reference/pulls#enum-fileviewedstate)`) |

The state of the file for the viewer.  |

### [PullRequestChangedFileConnection](#object-pullrequestchangedfileconnection)

Object

The connection type for PullRequestChangedFile.

#### Fields for `PullRequestChangedFileConnection`

| Name | Description  |

|

`edges` (`[[PullRequestChangedFileEdge]](/en/graphql/reference/pulls#object-pullrequestchangedfileedge)`) |

A list of edges.  |

|

`nodes` (`[[PullRequestChangedFile]](/en/graphql/reference/pulls#object-pullrequestchangedfile)`) |

A list of nodes.  |

|

`pageInfo` (`[PageInfo!](/en/graphql/reference/other#object-pageinfo)`) |

Information to aid in pagination.  |

|

`totalCount` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Identifies the total count of items in the connection.  |

### [PullRequestChangedFileEdge](#object-pullrequestchangedfileedge)

Object

An edge in a connection.

#### Fields for `PullRequestChangedFileEdge`

| Name | Description  |

|

`cursor` (`[String!](/en/graphql/reference/other#scalar-string)`) |

A cursor for use in pagination.  |

|

`node` (`[PullRequestChangedFile](/en/graphql/reference/pulls#object-pullrequestchangedfile)`) |

The item at the end of the edge.  |

### [PullRequestCommit](#object-pullrequestcommit)

Object

Represents a Git commit part of a pull request.

#### `PullRequestCommit` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`
- `[UniformResourceLocatable](/en/graphql/reference/meta#interface-uniformresourcelocatable)`

#### Fields for `PullRequestCommit`

| Name | Description  |

|

`commit` (`[Commit!](/en/graphql/reference/commits#object-commit)`) |

The Git commit object.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the PullRequestCommit object.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request this commit belongs to.  |

|

`resourcePath` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP path for this pull request commit.  |

|

`url` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP URL for this pull request commit.  |

### [PullRequestCommitCommentThread](#object-pullrequestcommitcommentthread)

Object

Represents a commit comment thread part of a pull request.

#### `PullRequestCommitCommentThread` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`
- `[RepositoryNode](/en/graphql/reference/repos#interface-repositorynode)`

#### Fields for `PullRequestCommitCommentThread`

| Name | Description  |

|

`comments` (`[CommitCommentConnection!](/en/graphql/reference/commits#object-commitcommentconnection)`) |

The comments that exist in this thread.

Arguments for `comments`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`commit` (`[Commit!](/en/graphql/reference/commits#object-commit)`) |

The commit the comments were made on.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the PullRequestCommitCommentThread object.  |

|

`path` (`[String](/en/graphql/reference/other#scalar-string)`) |

The file the comments were made on.  |

|

`position` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The position in the diff for the commit that the comment was made on.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request this commit comment thread belongs to.  |

|

`repository` (`[Repository!](/en/graphql/reference/repos#object-repository)`) |

The repository associated with this node.  |

### [PullRequestCommitConnection](#object-pullrequestcommitconnection)

Object

The connection type for PullRequestCommit.

#### Fields for `PullRequestCommitConnection`

| Name | Description  |

|

`edges` (`[[PullRequestCommitEdge]](/en/graphql/reference/pulls#object-pullrequestcommitedge)`) |

A list of edges.  |

|

`nodes` (`[[PullRequestCommit]](/en/graphql/reference/pulls#object-pullrequestcommit)`) |

A list of nodes.  |

|

`pageInfo` (`[PageInfo!](/en/graphql/reference/other#object-pageinfo)`) |

Information to aid in pagination.  |

|

`totalCount` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Identifies the total count of items in the connection.  |

### [PullRequestCommitEdge](#object-pullrequestcommitedge)

Object

An edge in a connection.

#### Fields for `PullRequestCommitEdge`

| Name | Description  |

|

`cursor` (`[String!](/en/graphql/reference/other#scalar-string)`) |

A cursor for use in pagination.  |

|

`node` (`[PullRequestCommit](/en/graphql/reference/pulls#object-pullrequestcommit)`) |

The item at the end of the edge.  |

### [PullRequestConnection](#object-pullrequestconnection)

Object

The connection type for PullRequest.

#### Fields for `PullRequestConnection`

| Name | Description  |

|

`edges` (`[[PullRequestEdge]](/en/graphql/reference/pulls#object-pullrequestedge)`) |

A list of edges.  |

|

`nodes` (`[[PullRequest]](/en/graphql/reference/pulls#object-pullrequest)`) |

A list of nodes.  |

|

`pageInfo` (`[PageInfo!](/en/graphql/reference/other#object-pageinfo)`) |

Information to aid in pagination.  |

|

`totalCount` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Identifies the total count of items in the connection.  |

### [PullRequestContributionsByRepository](#object-pullrequestcontributionsbyrepository)

Object

This aggregates pull requests opened by a user within one repository.

#### Fields for `PullRequestContributionsByRepository`

| Name | Description  |

|

`contributions` (`[CreatedPullRequestContributionConnection!](/en/graphql/reference/users#object-createdpullrequestcontributionconnection)`) |

The pull request contributions.

Arguments for `contributions`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`orderBy` (`[ContributionOrder](/en/graphql/reference/users#input-object-contributionorder)`)

Ordering options for contributions returned from the connection.  |

|

`repository` (`[Repository!](/en/graphql/reference/repos#object-repository)`) |

The repository in which the pull requests were opened.  |

### [PullRequestCreationCapConfig](#object-pullrequestcreationcapconfig)

Object

Users who are exempt from the pull request creation cap on a repository.

#### Fields for `PullRequestCreationCapConfig`

| Name | Description  |

|

`bypassedUsers` (`[UserConnection!](/en/graphql/reference/users#object-userconnection)`) |

Users who are exempt from the pull request creation cap.

Arguments for `bypassedUsers`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

### [PullRequestEdge](#object-pullrequestedge)

Object

An edge in a connection.

#### Fields for `PullRequestEdge`

| Name | Description  |

|

`cursor` (`[String!](/en/graphql/reference/other#scalar-string)`) |

A cursor for use in pagination.  |

|

`node` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

The item at the end of the edge.  |

### [PullRequestParameters](#object-pullrequestparameters)

Object

Require all commits be made to a non-target branch and submitted via a pull request before they can be merged.

#### Fields for `PullRequestParameters`

| Name | Description  |

|

`allowedMergeMethods` (`[[PullRequestAllowedMergeMethods!]](/en/graphql/reference/pulls#enum-pullrequestallowedmergemethods)`) |

Array of allowed merge methods. Allowed values include `merge`, `squash`, and `rebase`. At least one option must be enabled.  |

|

`dismissStaleReviewsOnPush` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

New, reviewable commits pushed will dismiss previous pull request review approvals.  |

|

`requireCodeOwnerReview` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Require an approving review in pull requests that modify files that have a designated code owner.  |

|

`requireLastPushApproval` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether the most recent reviewable push must be approved by someone other than the person who pushed it.  |

|

`requiredApprovingReviewCount` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

The number of approving reviews that are required before a pull request can be merged.  |

|

`requiredReviewThreadResolution` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

All conversations on code must be resolved before a pull request can be merged.  |

|

`requiredReviewers` (`[[RequiredReviewerConfiguration!]](/en/graphql/reference/pulls#object-requiredreviewerconfiguration)`) |

This field is in beta and subject to change. A collection of reviewers and associated file patterns. Each reviewer has a list of file patterns which determine the files that reviewer is required to review.  |

### [PullRequestReview](#object-pullrequestreview)

Object

A review object for a given pull request.

#### `PullRequestReview` Implements

- `[Comment](/en/graphql/reference/issues#interface-comment)`
- `[Deletable](/en/graphql/reference/issues#interface-deletable)`
- `[Minimizable](/en/graphql/reference/issues#interface-minimizable)`
- `[Node](/en/graphql/reference/meta#interface-node)`
- `[Reactable](/en/graphql/reference/reactions#interface-reactable)`
- `[RepositoryNode](/en/graphql/reference/repos#interface-repositorynode)`
- `[Updatable](/en/graphql/reference/issues#interface-updatable)`
- `[UpdatableComment](/en/graphql/reference/issues#interface-updatablecomment)`

#### Fields for `PullRequestReview`

| Name | Description  |

|

`author` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

The actor who authored the comment.  |

|

`authorAssociation` (`[CommentAuthorAssociation!](/en/graphql/reference/issues#enum-commentauthorassociation)`) |

Author's association with the subject of the comment.  |

|

`authorCanPushToRepository` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Indicates whether the author of this review has push access to the repository.  |

|

`body` (`[String!](/en/graphql/reference/other#scalar-string)`) |

Identifies the pull request review body.  |

|

`bodyHTML` (`[HTML!](/en/graphql/reference/other#scalar-html)`) |

The body rendered to HTML.  |

|

`bodyText` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The body of this review rendered as plain text.  |

|

`comments` (`[PullRequestReviewCommentConnection!](/en/graphql/reference/pulls#object-pullrequestreviewcommentconnection)`) |

A list of review comments for the current pull request review.

Arguments for `comments`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`commit` (`[Commit](/en/graphql/reference/commits#object-commit)`) |

Identifies the commit associated with this pull request review.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`createdViaEmail` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if this comment was created via an email reply.  |

|

`databaseId` (`[Int](/en/graphql/reference/other#scalar-int)`) |

Identifies the primary key from the database.

Warning

`databaseId` is deprecated.

`databaseId` will be removed because it does not support 64-bit signed integer identifiers. Use `fullDatabaseId` instead. Removal on 2024-07-01 UTC.  |

|

`editor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

The actor who edited the comment.  |

|

`fullDatabaseId` (`[BigInt](/en/graphql/reference/other#scalar-bigint)`) |

Identifies the primary key from the database as a BigInt.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the PullRequestReview object.  |

|

`includesCreatedEdit` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if this comment was edited and includes an edit with the creation data.  |

|

`isMinimized` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Returns whether or not a comment has been minimized.  |

|

`lastEditedAt` (`[DateTime](/en/graphql/reference/other#scalar-datetime)`) |

The moment the editor made the last edit.  |

|

`minimizedReason` (`[String](/en/graphql/reference/other#scalar-string)`) |

Returns why the comment was minimized. One of `abuse`, `off-topic`, `outdated`, `resolved`, `duplicate`, `spam`, and `low-quality`. Note that the case and formatting of these values differs from the inputs to the `MinimizeComment` mutation.  |

|

`onBehalfOf` (`[TeamConnection!](/en/graphql/reference/teams#object-teamconnection)`) |

A list of teams that this review was made on behalf of.

Arguments for `onBehalfOf`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`publishedAt` (`[DateTime](/en/graphql/reference/other#scalar-datetime)`) |

Identifies when the comment was published at.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

Identifies the pull request associated with this pull request review.  |

|

`reactionGroups` (`[[ReactionGroup!]](/en/graphql/reference/reactions#object-reactiongroup)`) |

A list of reactions grouped by content left on the subject.  |

|

`reactions` (`[ReactionConnection!](/en/graphql/reference/reactions#object-reactionconnection)`) |

A list of Reactions left on the Issue.

Arguments for `reactions`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`content` (`[ReactionContent](/en/graphql/reference/reactions#enum-reactioncontent)`)

Allows filtering Reactions by emoji.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`orderBy` (`[ReactionOrder](/en/graphql/reference/reactions#input-object-reactionorder)`)

Allows specifying the order in which reactions are returned.  |

|

`repository` (`[Repository!](/en/graphql/reference/repos#object-repository)`) |

The repository associated with this node.  |

|

`resourcePath` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP path permalink for this PullRequestReview.  |

|

`state` (`[PullRequestReviewState!](/en/graphql/reference/pulls#enum-pullrequestreviewstate)`) |

Identifies the current state of the pull request review.  |

|

`submittedAt` (`[DateTime](/en/graphql/reference/other#scalar-datetime)`) |

Identifies when the Pull Request Review was submitted.  |

|

`updatedAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was last updated.  |

|

`url` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP URL permalink for this PullRequestReview.  |

|

`userContentEdits` (`[UserContentEditConnection](/en/graphql/reference/users#object-usercontenteditconnection)`) |

A list of edits to this content.

Arguments for `userContentEdits`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`viewerCanDelete` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if the current viewer can delete this object.  |

|

`viewerCanMinimize` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if the current viewer can minimize this object.  |

|

`viewerCanReact` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Can user react to this subject.  |

|

`viewerCanUnminimize` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if the current viewer can unminimize this object.  |

|

`viewerCanUpdate` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if the current viewer can update this object.  |

|

`viewerCannotUpdateReasons` (`[[CommentCannotUpdateReason!]!](/en/graphql/reference/issues#enum-commentcannotupdatereason)`) |

Reasons why the current viewer can not update this comment.  |

|

`viewerDidAuthor` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Did the viewer author this comment.  |

### [PullRequestReviewComment](#object-pullrequestreviewcomment)

Object

A review comment associated with a given repository pull request.

#### `PullRequestReviewComment` Implements

- `[Comment](/en/graphql/reference/issues#interface-comment)`
- `[Deletable](/en/graphql/reference/issues#interface-deletable)`
- `[Minimizable](/en/graphql/reference/issues#interface-minimizable)`
- `[Node](/en/graphql/reference/meta#interface-node)`
- `[Reactable](/en/graphql/reference/reactions#interface-reactable)`
- `[RepositoryNode](/en/graphql/reference/repos#interface-repositorynode)`
- `[Updatable](/en/graphql/reference/issues#interface-updatable)`
- `[UpdatableComment](/en/graphql/reference/issues#interface-updatablecomment)`

#### Fields for `PullRequestReviewComment`

| Name | Description  |

|

`author` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

The actor who authored the comment.  |

|

`authorAssociation` (`[CommentAuthorAssociation!](/en/graphql/reference/issues#enum-commentauthorassociation)`) |

Author's association with the subject of the comment.  |

|

`body` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The comment body of this review comment.  |

|

`bodyHTML` (`[HTML!](/en/graphql/reference/other#scalar-html)`) |

The body rendered to HTML.  |

|

`bodyText` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The comment body of this review comment rendered as plain text.  |

|

`commit` (`[Commit](/en/graphql/reference/commits#object-commit)`) |

Identifies the commit associated with the comment.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies when the comment was created.  |

|

`createdViaEmail` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if this comment was created via an email reply.  |

|

`databaseId` (`[Int](/en/graphql/reference/other#scalar-int)`) |

Identifies the primary key from the database.

Warning

`databaseId` is deprecated.

`databaseId` will be removed because it does not support 64-bit signed integer identifiers. Use `fullDatabaseId` instead. Removal on 2024-07-01 UTC.  |

|

`diffHunk` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The diff hunk to which the comment applies.  |

|

`draftedAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies when the comment was created in a draft state.  |

|

`editor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

The actor who edited the comment.  |

|

`fullDatabaseId` (`[BigInt](/en/graphql/reference/other#scalar-bigint)`) |

Identifies the primary key from the database as a BigInt.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the PullRequestReviewComment object.  |

|

`includesCreatedEdit` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if this comment was edited and includes an edit with the creation data.  |

|

`isMinimized` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Returns whether or not a comment has been minimized.  |

|

`lastEditedAt` (`[DateTime](/en/graphql/reference/other#scalar-datetime)`) |

The moment the editor made the last edit.  |

|

`line` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The end line number on the file to which the comment applies.  |

|

`minimizedReason` (`[String](/en/graphql/reference/other#scalar-string)`) |

Returns why the comment was minimized. One of `abuse`, `off-topic`, `outdated`, `resolved`, `duplicate`, `spam`, and `low-quality`. Note that the case and formatting of these values differs from the inputs to the `MinimizeComment` mutation.  |

|

`originalCommit` (`[Commit](/en/graphql/reference/commits#object-commit)`) |

Identifies the original commit associated with the comment.  |

|

`originalLine` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The end line number on the file to which the comment applied when it was first created.  |

|

`originalPosition` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

The original line index in the diff to which the comment applies.

Warning

`originalPosition` is deprecated.

We are phasing out diff-relative positioning for PR comments Removal on 2023-10-01 UTC.  |

|

`originalStartLine` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The start line number on the file to which the comment applied when it was first created.  |

|

`outdated` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Identifies when the comment body is outdated.  |

|

`path` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The path to which the comment applies.  |

|

`position` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The line index in the diff to which the comment applies.

Warning

`position` is deprecated.

We are phasing out diff-relative positioning for PR comments Use the `line` and `startLine` fields instead, which are file line numbers instead of diff line numbers Removal on 2023-10-01 UTC.  |

|

`publishedAt` (`[DateTime](/en/graphql/reference/other#scalar-datetime)`) |

Identifies when the comment was published at.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request associated with this review comment.  |

|

`pullRequestReview` (`[PullRequestReview](/en/graphql/reference/pulls#object-pullrequestreview)`) |

The pull request review associated with this review comment.  |

|

`reactionGroups` (`[[ReactionGroup!]](/en/graphql/reference/reactions#object-reactiongroup)`) |

A list of reactions grouped by content left on the subject.  |

|

`reactions` (`[ReactionConnection!](/en/graphql/reference/reactions#object-reactionconnection)`) |

A list of Reactions left on the Issue.

Arguments for `reactions`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`content` (`[ReactionContent](/en/graphql/reference/reactions#enum-reactioncontent)`)

Allows filtering Reactions by emoji.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`orderBy` (`[ReactionOrder](/en/graphql/reference/reactions#input-object-reactionorder)`)

Allows specifying the order in which reactions are returned.  |

|

`replyTo` (`[PullRequestReviewComment](/en/graphql/reference/pulls#object-pullrequestreviewcomment)`) |

The comment this is a reply to.  |

|

`repository` (`[Repository!](/en/graphql/reference/repos#object-repository)`) |

The repository associated with this node.  |

|

`resourcePath` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP path permalink for this review comment.  |

|

`startLine` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The start line number on the file to which the comment applies.  |

|

`state` (`[PullRequestReviewCommentState!](/en/graphql/reference/pulls#enum-pullrequestreviewcommentstate)`) |

Identifies the state of the comment.  |

|

`subjectType` (`[PullRequestReviewThreadSubjectType!](/en/graphql/reference/pulls#enum-pullrequestreviewthreadsubjecttype)`) |

The level at which the comments in the corresponding thread are targeted, can be a diff line or a file.  |

|

`updatedAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies when the comment was last updated.  |

|

`url` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP URL permalink for this review comment.  |

|

`userContentEdits` (`[UserContentEditConnection](/en/graphql/reference/users#object-usercontenteditconnection)`) |

A list of edits to this content.

Arguments for `userContentEdits`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.  |

|

`viewerCanDelete` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if the current viewer can delete this object.  |

|

`viewerCanMinimize` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if the current viewer can minimize this object.  |

|

`viewerCanReact` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Can user react to this subject.  |

|

`viewerCanUnminimize` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if the current viewer can unminimize this object.  |

|

`viewerCanUpdate` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Check if the current viewer can update this object.  |

|

`viewerCannotUpdateReasons` (`[[CommentCannotUpdateReason!]!](/en/graphql/reference/issues#enum-commentcannotupdatereason)`) |

Reasons why the current viewer can not update this comment.  |

|

`viewerDidAuthor` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Did the viewer author this comment.  |

### [PullRequestReviewCommentConnection](#object-pullrequestreviewcommentconnection)

Object

The connection type for PullRequestReviewComment.

#### Fields for `PullRequestReviewCommentConnection`

| Name | Description  |

|

`edges` (`[[PullRequestReviewCommentEdge]](/en/graphql/reference/pulls#object-pullrequestreviewcommentedge)`) |

A list of edges.  |

|

`nodes` (`[[PullRequestReviewComment]](/en/graphql/reference/pulls#object-pullrequestreviewcomment)`) |

A list of nodes.  |

|

`pageInfo` (`[PageInfo!](/en/graphql/reference/other#object-pageinfo)`) |

Information to aid in pagination.  |

|

`totalCount` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Identifies the total count of items in the connection.  |

### [PullRequestReviewCommentEdge](#object-pullrequestreviewcommentedge)

Object

An edge in a connection.

#### Fields for `PullRequestReviewCommentEdge`

| Name | Description  |

|

`cursor` (`[String!](/en/graphql/reference/other#scalar-string)`) |

A cursor for use in pagination.  |

|

`node` (`[PullRequestReviewComment](/en/graphql/reference/pulls#object-pullrequestreviewcomment)`) |

The item at the end of the edge.  |

### [PullRequestReviewConnection](#object-pullrequestreviewconnection)

Object

The connection type for PullRequestReview.

#### Fields for `PullRequestReviewConnection`

| Name | Description  |

|

`edges` (`[[PullRequestReviewEdge]](/en/graphql/reference/pulls#object-pullrequestreviewedge)`) |

A list of edges.  |

|

`nodes` (`[[PullRequestReview]](/en/graphql/reference/pulls#object-pullrequestreview)`) |

A list of nodes.  |

|

`pageInfo` (`[PageInfo!](/en/graphql/reference/other#object-pageinfo)`) |

Information to aid in pagination.  |

|

`totalCount` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Identifies the total count of items in the connection.  |

### [PullRequestReviewContributionsByRepository](#object-pullrequestreviewcontributionsbyrepository)

Object

This aggregates pull request reviews made by a user within one repository.

#### Fields for `PullRequestReviewContributionsByRepository`

| Name | Description  |

|

`contributions` (`[CreatedPullRequestReviewContributionConnection!](/en/graphql/reference/users#object-createdpullrequestreviewcontributionconnection)`) |

The pull request review contributions.

Arguments for `contributions`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`orderBy` (`[ContributionOrder](/en/graphql/reference/users#input-object-contributionorder)`)

Ordering options for contributions returned from the connection.  |

|

`repository` (`[Repository!](/en/graphql/reference/repos#object-repository)`) |

The repository in which the pull request reviews were made.  |

### [PullRequestReviewEdge](#object-pullrequestreviewedge)

Object

An edge in a connection.

#### Fields for `PullRequestReviewEdge`

| Name | Description  |

|

`cursor` (`[String!](/en/graphql/reference/other#scalar-string)`) |

A cursor for use in pagination.  |

|

`node` (`[PullRequestReview](/en/graphql/reference/pulls#object-pullrequestreview)`) |

The item at the end of the edge.  |

### [PullRequestReviewThread](#object-pullrequestreviewthread)

Object

A threaded list of comments for a given pull request.

#### `PullRequestReviewThread` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `PullRequestReviewThread`

| Name | Description  |

|

`comments` (`[PullRequestReviewCommentConnection!](/en/graphql/reference/pulls#object-pullrequestreviewcommentconnection)`) |

A list of pull request comments associated with the thread.

Arguments for `comments`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`skip` (`[Int](/en/graphql/reference/other#scalar-int)`)

Skips the first n elements in the list.  |

|

`diffSide` (`[DiffSide!](/en/graphql/reference/pulls#enum-diffside)`) |

The side of the diff on which this thread was placed.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the PullRequestReviewThread object.  |

|

`isCollapsed` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether or not the thread has been collapsed (resolved).  |

|

`isOutdated` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Indicates whether this thread was outdated by newer changes.  |

|

`isResolved` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether this thread has been resolved.  |

|

`line` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The line in the file to which this thread refers.  |

|

`originalLine` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The original line in the file to which this thread refers.  |

|

`originalStartLine` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The original start line in the file to which this thread refers (multi-line only).  |

|

`path` (`[String!](/en/graphql/reference/other#scalar-string)`) |

Identifies the file path of this thread.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

Identifies the pull request associated with this thread.  |

|

`repository` (`[Repository!](/en/graphql/reference/repos#object-repository)`) |

Identifies the repository associated with this thread.  |

|

`resolvedBy` (`[User](/en/graphql/reference/users#object-user)`) |

The user who resolved this thread.  |

|

`startDiffSide` (`[DiffSide](/en/graphql/reference/pulls#enum-diffside)`) |

The side of the diff that the first line of the thread starts on (multi-line only).  |

|

`startLine` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The start line in the file to which this thread refers (multi-line only).  |

|

`subjectType` (`[PullRequestReviewThreadSubjectType!](/en/graphql/reference/pulls#enum-pullrequestreviewthreadsubjecttype)`) |

The level at which the comments in the corresponding thread are targeted, can be a diff line or a file.  |

|

`viewerCanReply` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Indicates whether the current viewer can reply to this thread.  |

|

`viewerCanResolve` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether or not the viewer can resolve this thread.  |

|

`viewerCanUnresolve` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether or not the viewer can unresolve this thread.  |

### [PullRequestReviewThreadConnection](#object-pullrequestreviewthreadconnection)

Object

Review comment threads for a pull request review.

#### Fields for `PullRequestReviewThreadConnection`

| Name | Description  |

|

`edges` (`[[PullRequestReviewThreadEdge]](/en/graphql/reference/pulls#object-pullrequestreviewthreadedge)`) |

A list of edges.  |

|

`nodes` (`[[PullRequestReviewThread]](/en/graphql/reference/pulls#object-pullrequestreviewthread)`) |

A list of nodes.  |

|

`pageInfo` (`[PageInfo!](/en/graphql/reference/other#object-pageinfo)`) |

Information to aid in pagination.  |

|

`totalCount` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Identifies the total count of items in the connection.  |

### [PullRequestReviewThreadEdge](#object-pullrequestreviewthreadedge)

Object

An edge in a connection.

#### Fields for `PullRequestReviewThreadEdge`

| Name | Description  |

|

`cursor` (`[String!](/en/graphql/reference/other#scalar-string)`) |

A cursor for use in pagination.  |

|

`node` (`[PullRequestReviewThread](/en/graphql/reference/pulls#object-pullrequestreviewthread)`) |

The item at the end of the edge.  |

### [PullRequestRevisionMarker](#object-pullrequestrevisionmarker)

Object

Represents the latest point in the pull request timeline for which the viewer has seen the pull request's commits.

#### Fields for `PullRequestRevisionMarker`

| Name | Description  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`lastSeenCommit` (`[Commit!](/en/graphql/reference/commits#object-commit)`) |

The last commit the viewer has seen.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

The pull request to which the marker belongs.  |

### [PullRequestTemplate](#object-pullrequesttemplate)

Object

A repository pull request template.

#### Fields for `PullRequestTemplate`

| Name | Description  |

|

`body` (`[String](/en/graphql/reference/other#scalar-string)`) |

The body of the template.  |

|

`filename` (`[String](/en/graphql/reference/other#scalar-string)`) |

The filename of the template.  |

|

`repository` (`[Repository!](/en/graphql/reference/repos#object-repository)`) |

The repository the template belongs to.  |

### [PullRequestThread](#object-pullrequestthread)

Object

A threaded list of comments for a given pull request.

#### `PullRequestThread` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `PullRequestThread`

| Name | Description  |

|

`comments` (`[PullRequestReviewCommentConnection!](/en/graphql/reference/pulls#object-pullrequestreviewcommentconnection)`) |

A list of pull request comments associated with the thread.

Arguments for `comments`

-

`after` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come after the specified cursor.

-

`before` (`[String](/en/graphql/reference/other#scalar-string)`)

Returns the elements in the list that come before the specified cursor.

-

`first` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the first n elements from the list.

-

`last` (`[Int](/en/graphql/reference/other#scalar-int)`)

Returns the last n elements from the list.

-

`skip` (`[Int](/en/graphql/reference/other#scalar-int)`)

Skips the first n elements in the list.  |

|

`diffSide` (`[DiffSide!](/en/graphql/reference/pulls#enum-diffside)`) |

The side of the diff on which this thread was placed.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the PullRequestThread object.  |

|

`isCollapsed` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether or not the thread has been collapsed (resolved).  |

|

`isOutdated` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Indicates whether this thread was outdated by newer changes.  |

|

`isResolved` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether this thread has been resolved.  |

|

`line` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The line in the file to which this thread refers.  |

|

`path` (`[String!](/en/graphql/reference/other#scalar-string)`) |

Identifies the file path of this thread.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

Identifies the pull request associated with this thread.  |

|

`repository` (`[Repository!](/en/graphql/reference/repos#object-repository)`) |

Identifies the repository associated with this thread.  |

|

`resolvedBy` (`[User](/en/graphql/reference/users#object-user)`) |

The user who resolved this thread.  |

|

`startDiffSide` (`[DiffSide](/en/graphql/reference/pulls#enum-diffside)`) |

The side of the diff that the first line of the thread starts on (multi-line only).  |

|

`startLine` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The line of the first file diff in the thread.  |

|

`subjectType` (`[PullRequestReviewThreadSubjectType!](/en/graphql/reference/pulls#enum-pullrequestreviewthreadsubjecttype)`) |

The level at which the comments in the corresponding thread are targeted, can be a diff line or a file.  |

|

`viewerCanReply` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Indicates whether the current viewer can reply to this thread.  |

|

`viewerCanResolve` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether or not the viewer can resolve this thread.  |

|

`viewerCanUnresolve` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether or not the viewer can unresolve this thread.  |

### [PullRequestTimelineConnection](#object-pullrequesttimelineconnection)

Object

The connection type for PullRequestTimelineItem.

#### Fields for `PullRequestTimelineConnection`

| Name | Description  |

|

`edges` (`[[PullRequestTimelineItemEdge]](/en/graphql/reference/pulls#object-pullrequesttimelineitemedge)`) |

A list of edges.  |

|

`nodes` (`[[PullRequestTimelineItem]](/en/graphql/reference/pulls#union-pullrequesttimelineitem)`) |

A list of nodes.  |

|

`pageInfo` (`[PageInfo!](/en/graphql/reference/other#object-pageinfo)`) |

Information to aid in pagination.  |

|

`totalCount` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Identifies the total count of items in the connection.  |

### [PullRequestTimelineItemEdge](#object-pullrequesttimelineitemedge)

Object

An edge in a connection.

#### Fields for `PullRequestTimelineItemEdge`

| Name | Description  |

|

`cursor` (`[String!](/en/graphql/reference/other#scalar-string)`) |

A cursor for use in pagination.  |

|

`node` (`[PullRequestTimelineItem](/en/graphql/reference/pulls#union-pullrequesttimelineitem)`) |

The item at the end of the edge.  |

### [PullRequestTimelineItemsConnection](#object-pullrequesttimelineitemsconnection)

Object

The connection type for PullRequestTimelineItems.

#### Fields for `PullRequestTimelineItemsConnection`

| Name | Description  |

|

`edges` (`[[PullRequestTimelineItemsEdge]](/en/graphql/reference/pulls#object-pullrequesttimelineitemsedge)`) |

A list of edges.  |

|

`filteredCount` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Identifies the count of items after applying `before` and `after` filters.  |

|

`nodes` (`[[PullRequestTimelineItems]](/en/graphql/reference/pulls#union-pullrequesttimelineitems)`) |

A list of nodes.  |

|

`pageCount` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Identifies the count of items after applying `before`/`after` filters and `first`/`last`/`skip` slicing.  |

|

`pageInfo` (`[PageInfo!](/en/graphql/reference/other#object-pageinfo)`) |

Information to aid in pagination.  |

|

`totalCount` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Identifies the total count of items in the connection.  |

|

`updatedAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the timeline was last updated.  |

### [PullRequestTimelineItemsEdge](#object-pullrequesttimelineitemsedge)

Object

An edge in a connection.

#### Fields for `PullRequestTimelineItemsEdge`

| Name | Description  |

|

`cursor` (`[String!](/en/graphql/reference/other#scalar-string)`) |

A cursor for use in pagination.  |

|

`node` (`[PullRequestTimelineItems](/en/graphql/reference/pulls#union-pullrequesttimelineitems)`) |

The item at the end of the edge.  |

### [ReadyForReviewEvent](#object-readyforreviewevent)

Object

Represents a`ready_for_review`event on a given pull request.

#### `ReadyForReviewEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`
- `[UniformResourceLocatable](/en/graphql/reference/meta#interface-uniformresourcelocatable)`

#### Fields for `ReadyForReviewEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the ReadyForReviewEvent object.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

|

`resourcePath` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP path for this ready for review event.  |

|

`url` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP URL for this ready for review event.  |

### [RemovedFromMergeQueueEvent](#object-removedfrommergequeueevent)

Object

Represents a`removed_from_merge_queue`event on a given pull request.

#### `RemovedFromMergeQueueEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `RemovedFromMergeQueueEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`beforeCommit` (`[Commit](/en/graphql/reference/commits#object-commit)`) |

Identifies the before commit SHA for the`removed_from_merge_queue`event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`enqueuer` (`[User](/en/graphql/reference/users#object-user)`) |

The user who removed this Pull Request from the merge queue.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the RemovedFromMergeQueueEvent object.  |

|

`mergeQueue` (`[MergeQueue](/en/graphql/reference/pulls#object-mergequeue)`) |

The merge queue where this pull request was removed from.  |

|

`pullRequest` (`[PullRequest](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

|

`reason` (`[String](/en/graphql/reference/other#scalar-string)`) |

The reason this pull request was removed from the queue.  |

### [RequestedReviewerConnection](#object-requestedreviewerconnection)

Object

The connection type for RequestedReviewer.

#### Fields for `RequestedReviewerConnection`

| Name | Description  |

|

`edges` (`[[RequestedReviewerEdge]](/en/graphql/reference/pulls#object-requestedrevieweredge)`) |

A list of edges.  |

|

`nodes` (`[[RequestedReviewer]](/en/graphql/reference/pulls#union-requestedreviewer)`) |

A list of nodes.  |

|

`pageInfo` (`[PageInfo!](/en/graphql/reference/other#object-pageinfo)`) |

Information to aid in pagination.  |

|

`totalCount` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Identifies the total count of items in the connection.  |

### [RequestedReviewerEdge](#object-requestedrevieweredge)

Object

An edge in a connection.

#### Fields for `RequestedReviewerEdge`

| Name | Description  |

|

`cursor` (`[String!](/en/graphql/reference/other#scalar-string)`) |

A cursor for use in pagination.  |

|

`node` (`[RequestedReviewer](/en/graphql/reference/pulls#union-requestedreviewer)`) |

The item at the end of the edge.  |

### [RequiredReviewerConfiguration](#object-requiredreviewerconfiguration)

Object

A reviewing team, and file patterns describing which files they must approve changes to.

#### Fields for `RequiredReviewerConfiguration`

| Name | Description  |

|

`filePatterns` (`[[String!]!](/en/graphql/reference/other#scalar-string)`) |

Array of file patterns. Pull requests which change matching files must be approved by the specified team. File patterns use fnmatch syntax.  |

|

`minimumApprovals` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Minimum number of approvals required from the specified team. If set to zero, the team will be added to the pull request but approval is optional.  |

|

`reviewerId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

Node ID of the team which must review changes to matching files.  |

### [ReviewDismissedEvent](#object-reviewdismissedevent)

Object

Represents a`review_dismissed`event on a given issue or pull request.

#### `ReviewDismissedEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`
- `[UniformResourceLocatable](/en/graphql/reference/meta#interface-uniformresourcelocatable)`

#### Fields for `ReviewDismissedEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`databaseId` (`[Int](/en/graphql/reference/other#scalar-int)`) |

Identifies the primary key from the database.  |

|

`dismissalMessage` (`[String](/en/graphql/reference/other#scalar-string)`) |

Identifies the optional message associated with the`review_dismissed`event.  |

|

`dismissalMessageHTML` (`[String](/en/graphql/reference/other#scalar-string)`) |

Identifies the optional message associated with the event, rendered to HTML.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the ReviewDismissedEvent object.  |

|

`previousReviewState` (`[PullRequestReviewState!](/en/graphql/reference/pulls#enum-pullrequestreviewstate)`) |

Identifies the previous state of the review with the`review_dismissed`event.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

|

`pullRequestCommit` (`[PullRequestCommit](/en/graphql/reference/pulls#object-pullrequestcommit)`) |

Identifies the commit which caused the review to become stale.  |

|

`resourcePath` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP path for this review dismissed event.  |

|

`review` (`[PullRequestReview](/en/graphql/reference/pulls#object-pullrequestreview)`) |

Identifies the review associated with the`review_dismissed`event.  |

|

`url` (`[URI!](/en/graphql/reference/other#scalar-uri)`) |

The HTTP URL for this review dismissed event.  |

### [ReviewRequest](#object-reviewrequest)

Object

A request for a user to review a pull request.

#### `ReviewRequest` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `ReviewRequest`

| Name | Description  |

|

`asCodeOwner` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether this request was created for a code owner.  |

|

`databaseId` (`[Int](/en/graphql/reference/other#scalar-int)`) |

Identifies the primary key from the database.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the ReviewRequest object.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

Identifies the pull request associated with this review request.  |

|

`requestedReviewer` (`[RequestedReviewer](/en/graphql/reference/pulls#union-requestedreviewer)`) |

The reviewer that is requested.  |

### [ReviewRequestConnection](#object-reviewrequestconnection)

Object

The connection type for ReviewRequest.

#### Fields for `ReviewRequestConnection`

| Name | Description  |

|

`edges` (`[[ReviewRequestEdge]](/en/graphql/reference/pulls#object-reviewrequestedge)`) |

A list of edges.  |

|

`nodes` (`[[ReviewRequest]](/en/graphql/reference/pulls#object-reviewrequest)`) |

A list of nodes.  |

|

`pageInfo` (`[PageInfo!](/en/graphql/reference/other#object-pageinfo)`) |

Information to aid in pagination.  |

|

`totalCount` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Identifies the total count of items in the connection.  |

### [ReviewRequestedEvent](#object-reviewrequestedevent)

Object

Represents an`review_requested`event on a given pull request.

#### `ReviewRequestedEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `ReviewRequestedEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the ReviewRequestedEvent object.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

|

`requestedReviewer` (`[RequestedReviewer](/en/graphql/reference/pulls#union-requestedreviewer)`) |

Identifies the reviewer whose review was requested.  |

### [ReviewRequestEdge](#object-reviewrequestedge)

Object

An edge in a connection.

#### Fields for `ReviewRequestEdge`

| Name | Description  |

|

`cursor` (`[String!](/en/graphql/reference/other#scalar-string)`) |

A cursor for use in pagination.  |

|

`node` (`[ReviewRequest](/en/graphql/reference/pulls#object-reviewrequest)`) |

The item at the end of the edge.  |

### [ReviewRequestRemovedEvent](#object-reviewrequestremovedevent)

Object

Represents an`review_request_removed`event on a given pull request.

#### `ReviewRequestRemovedEvent` Implements

- `[Node](/en/graphql/reference/meta#interface-node)`

#### Fields for `ReviewRequestRemovedEvent`

| Name | Description  |

|

`actor` (`[Actor](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor who performed the event.  |

|

`createdAt` (`[DateTime!](/en/graphql/reference/other#scalar-datetime)`) |

Identifies the date and time when the object was created.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the ReviewRequestRemovedEvent object.  |

|

`pullRequest` (`[PullRequest!](/en/graphql/reference/pulls#object-pullrequest)`) |

PullRequest referenced by event.  |

|

`requestedReviewer` (`[RequestedReviewer](/en/graphql/reference/pulls#union-requestedreviewer)`) |

Identifies the reviewer whose review request was removed.  |

### [ReviewStatusHovercardContext](#object-reviewstatushovercardcontext)

Object

A hovercard context with a message describing the current code review state of the pull request.

#### `ReviewStatusHovercardContext` Implements

- `[HovercardContext](/en/graphql/reference/users#interface-hovercardcontext)`

#### Fields for `ReviewStatusHovercardContext`

| Name | Description  |

|

`message` (`[String!](/en/graphql/reference/other#scalar-string)`) |

A string describing this context.  |

|

`octicon` (`[String!](/en/graphql/reference/other#scalar-string)`) |

An octicon to accompany this context.  |

|

`reviewDecision` (`[PullRequestReviewDecision](/en/graphql/reference/pulls#enum-pullrequestreviewdecision)`) |

The current status of the pull request with respect to code review.  |

### [SuggestedReviewer](#object-suggestedreviewer)

Object

A suggestion to review a pull request based on a user's commit history and review comments.

#### Fields for `SuggestedReviewer`

| Name | Description  |

|

`isAuthor` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Is this suggestion based on past commits?.  |

|

`isCommenter` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Is this suggestion based on past review comments?.  |

|

`reviewer` (`[User!](/en/graphql/reference/users#object-user)`) |

Identifies the user suggested to review the pull request.  |

### [SuggestedReviewerActor](#object-suggestedrevieweractor)

Object

A suggestion to review a pull request based on an actor's commit history, review comments, and integrations.

#### Fields for `SuggestedReviewerActor`

| Name | Description  |

|

`isAuthor` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Is this suggestion based on past commits?.  |

|

`isCommenter` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Is this suggestion based on past review comments?.  |

|

`reviewer` (`[Actor!](/en/graphql/reference/users#interface-actor)`) |

Identifies the actor suggested to review the pull request.  |

### [SuggestedReviewerActorConnection](#object-suggestedrevieweractorconnection)

Object

A suggestion to review a pull request based on an actor's commit history, review comments, and integrations.

#### Fields for `SuggestedReviewerActorConnection`

| Name | Description  |

|

`edges` (`[[SuggestedReviewerActorEdge]](/en/graphql/reference/pulls#object-suggestedrevieweractoredge)`) |

A list of edges.  |

|

`nodes` (`[[SuggestedReviewerActor]](/en/graphql/reference/pulls#object-suggestedrevieweractor)`) |

A list of nodes.  |

|

`pageInfo` (`[PageInfo!](/en/graphql/reference/other#object-pageinfo)`) |

Information to aid in pagination.  |

|

`totalCount` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Identifies the total count of items in the connection.  |

### [SuggestedReviewerActorEdge](#object-suggestedrevieweractoredge)

Object

An edge in a connection.

#### Fields for `SuggestedReviewerActorEdge`

| Name | Description  |

|

`cursor` (`[String!](/en/graphql/reference/other#scalar-string)`) |

A cursor for use in pagination.  |

|

`node` (`[SuggestedReviewerActor](/en/graphql/reference/pulls#object-suggestedrevieweractor)`) |

The item at the end of the edge.  |

## [Interfaces](#interfaces)

### [RequirableByPullRequest](#interface-requirablebypullrequest)

Interface

Represents a type that can be required by a pull request for merging.

#### `RequirableByPullRequest` is implemented by

- `[CheckRun](/en/graphql/reference/checks#object-checkrun)`
- `[StatusContext](/en/graphql/reference/commits#object-statuscontext)`

#### Fields for `RequirableByPullRequest`

| Name | Description  |

|

`isRequired` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether this is required to pass before merging for a specific pull request.

Arguments for `isRequired`

-

`pullRequestId` (`[ID](/en/graphql/reference/other#scalar-id)`)

The id of the pull request this is required for.

-

`pullRequestNumber` (`[Int](/en/graphql/reference/other#scalar-int)`)

The number of the pull request this is required for.  |

## [Enums](#enums)

### [DiffSide](#enum-diffside)

Enum

The possible sides of a diff.

#### Values for `DiffSide`

| Name | Description  |

| `LEFT` |

The left side of the diff.  |

| `RIGHT` |

The right side of the diff.  |

### [FileViewedState](#enum-fileviewedstate)

Enum

The possible viewed states of a file .

#### Values for `FileViewedState`

| Name | Description  |

| `DISMISSED` |

The file has new changes since last viewed.  |

| `UNVIEWED` |

The file has not been marked as viewed.  |

| `VIEWED` |

The file has been marked as viewed.  |

### [MergeableState](#enum-mergeablestate)

Enum

Whether or not a PullRequest can be merged.

#### Values for `MergeableState`

| Name | Description  |

| `CONFLICTING` |

The pull request cannot be merged due to merge conflicts.  |

| `MERGEABLE` |

The pull request can be merged.  |

| `UNKNOWN` |

The mergeability of the pull request is still being calculated.  |

### [MergeQueueEntryState](#enum-mergequeueentrystate)

Enum

The possible states for a merge queue entry.

#### Values for `MergeQueueEntryState`

| Name | Description  |

| `AWAITING_CHECKS` |

The entry is currently waiting for checks to pass.  |

| `LOCKED` |

The entry is currently locked.  |

| `MERGEABLE` |

The entry is currently mergeable.  |

| `QUEUED` |

The entry is currently queued.  |

| `UNMERGEABLE` |

The entry is currently unmergeable.  |

### [MergeQueueGroupingStrategy](#enum-mergequeuegroupingstrategy)

Enum

When set to ALLGREEN, the merge commit created by merge queue for each PR in the group must pass all required checks to merge. When set to HEADGREEN, only the commit at the head of the merge group, i.e. the commit containing changes from all of the PRs in the group, must pass its required checks to merge.

#### Values for `MergeQueueGroupingStrategy`

| Name | Description  |

| `ALLGREEN` |

The merge commit created by merge queue for each PR in the group must pass all required checks to merge.  |

| `HEADGREEN` |

Only the commit at the head of the merge group must pass its required checks to merge.  |

### [MergeQueueMergeMethod](#enum-mergequeuemergemethod)

Enum

Method to use when merging changes from queued pull requests.

#### Values for `MergeQueueMergeMethod`

| Name | Description  |

| `MERGE` |

Merge commit.  |

| `REBASE` |

Rebase and merge.  |

| `SQUASH` |

Squash and merge.  |

### [MergeQueueMergingStrategy](#enum-mergequeuemergingstrategy)

Enum

The possible merging strategies for a merge queue.

#### Values for `MergeQueueMergingStrategy`

| Name | Description  |

| `ALLGREEN` |

Entries only allowed to merge if they are passing.  |

| `HEADGREEN` |

Failing Entires are allowed to merge if they are with a passing entry.  |

### [MergeStateStatus](#enum-mergestatestatus)

Enum

Detailed status information about a pull request merge.

#### Values for `MergeStateStatus`

| Name | Description  |

| `BEHIND` |

The head ref is out of date.  |

| `BLOCKED` |

The merge is blocked.  |

| `CLEAN` |

Mergeable and passing commit status.  |

| `DIRTY` |

The merge commit cannot be cleanly created.  |

| `DRAFT` |

The merge is blocked due to the pull request being a draft.  |

| `HAS_HOOKS` |

Mergeable with passing commit status and pre-receive hooks.  |

| `UNKNOWN` |

The state cannot currently be determined.  |

| `UNSTABLE` |

Mergeable with non-passing commit status.  |

### [PatchStatus](#enum-patchstatus)

Enum

The possible types of patch statuses.

#### Values for `PatchStatus`

| Name | Description  |

| `ADDED` |

The file was added. Git status 'A'.  |

| `CHANGED` |

The file's type was changed. Git status 'T'.  |

| `COPIED` |

The file was copied. Git status 'C'.  |

| `DELETED` |

The file was deleted. Git status 'D'.  |

| `MODIFIED` |

The file's contents were changed. Git status 'M'.  |

| `RENAMED` |

The file was renamed. Git status 'R'.  |

### [PullRequestAllowedMergeMethods](#enum-pullrequestallowedmergemethods)

Enum

Array of allowed merge methods. Allowed values include `merge`, `squash`, and `rebase`. At least one option must be enabled.

#### Values for `PullRequestAllowedMergeMethods`

| Name | Description  |

| `MERGE` |

Add all commits from the head branch to the base branch with a merge commit.  |

| `REBASE` |

Add all commits from the head branch onto the base branch individually.  |

| `SQUASH` |

Combine all commits from the head branch into a single commit in the base branch.  |

### [PullRequestBranchUpdateMethod](#enum-pullrequestbranchupdatemethod)

Enum

The possible methods for updating a pull request's head branch with the base branch.

#### Values for `PullRequestBranchUpdateMethod`

| Name | Description  |

| `MERGE` |

Update branch via merge.  |

| `REBASE` |

Update branch via rebase.  |

### [PullRequestCreationPolicy](#enum-pullrequestcreationpolicy)

Enum

The policy controlling who can create pull requests in a repository.

#### Values for `PullRequestCreationPolicy`

| Name | Description  |

| `ALL` |

Anyone can create pull requests.  |

| `COLLABORATORS_ONLY` |

Only collaborators can create pull requests.  |

### [PullRequestMergeMethod](#enum-pullrequestmergemethod)

Enum

Represents available types of methods to use when merging a pull request.

#### Values for `PullRequestMergeMethod`

| Name | Description  |

| `MERGE` |

Add all commits from the head branch to the base branch with a merge commit.  |

| `REBASE` |

Add all commits from the head branch onto the base branch individually.  |

| `SQUASH` |

Combine all commits from the head branch into a single commit in the base branch.  |

### [PullRequestOrderField](#enum-pullrequestorderfield)

Enum

Properties by which pull_requests connections can be ordered.

#### Values for `PullRequestOrderField`

| Name | Description  |

| `CREATED_AT` |

Order pull_requests by creation time.  |

| `UPDATED_AT` |

Order pull_requests by update time.  |

### [PullRequestReviewCommentState](#enum-pullrequestreviewcommentstate)

Enum

The possible states of a pull request review comment.

#### Values for `PullRequestReviewCommentState`

| Name | Description  |

| `PENDING` |

A comment that is part of a pending review.  |

| `SUBMITTED` |

A comment that is part of a submitted review.  |

### [PullRequestReviewDecision](#enum-pullrequestreviewdecision)

Enum

The review status of a pull request.

#### Values for `PullRequestReviewDecision`

| Name | Description  |

| `APPROVED` |

The pull request has received an approving review.  |

| `CHANGES_REQUESTED` |

Changes have been requested on the pull request.  |

| `REVIEW_REQUIRED` |

A review is required before the pull request can be merged.  |

### [PullRequestReviewEvent](#enum-pullrequestreviewevent)

Enum

The possible events to perform on a pull request review.

#### Values for `PullRequestReviewEvent`

| Name | Description  |

| `APPROVE` |

Submit feedback and approve merging these changes.  |

| `COMMENT` |

Submit general feedback without explicit approval.  |

| `DISMISS` |

Dismiss review so it now longer effects merging.  |

| `REQUEST_CHANGES` |

Submit feedback that must be addressed before merging.  |

### [PullRequestReviewState](#enum-pullrequestreviewstate)

Enum

The possible states of a pull request review.

#### Values for `PullRequestReviewState`

| Name | Description  |

| `APPROVED` |

A review allowing the pull request to merge.  |

| `CHANGES_REQUESTED` |

A review blocking the pull request from merging.  |

| `COMMENTED` |

An informational review.  |

| `DISMISSED` |

A review that has been dismissed.  |

| `PENDING` |

A review that has not yet been submitted.  |

### [PullRequestReviewThreadSubjectType](#enum-pullrequestreviewthreadsubjecttype)

Enum

The possible subject types of a pull request review comment.

#### Values for `PullRequestReviewThreadSubjectType`

| Name | Description  |

| `FILE` |

A comment that has been made against the file of a pull request.  |

| `LINE` |

A comment that has been made against the line of a pull request.  |

### [PullRequestState](#enum-pullrequeststate)

Enum

The possible states of a pull request.

#### Values for `PullRequestState`

| Name | Description  |

| `CLOSED` |

A pull request that has been closed without being merged.  |

| `MERGED` |

A pull request that has been closed by being merged.  |

| `OPEN` |

A pull request that is still open.  |

### [PullRequestUpdateState](#enum-pullrequestupdatestate)

Enum

The possible target states when updating a pull request.

#### Values for `PullRequestUpdateState`

| Name | Description  |

| `CLOSED` |

A pull request that has been closed without being merged.  |

| `OPEN` |

A pull request that is still open.  |

## [Unions](#unions)

### [PullRequestTimelineItem](#union-pullrequesttimelineitem)

Union

An item in a pull request timeline.

#### Possible types for `PullRequestTimelineItem`

- [`AssignedEvent`](/en/graphql/reference/issues#object-assignedevent)
- [`BaseRefDeletedEvent`](/en/graphql/reference/pulls#object-baserefdeletedevent)
- [`BaseRefForcePushedEvent`](/en/graphql/reference/pulls#object-baserefforcepushedevent)
- [`ClosedEvent`](/en/graphql/reference/issues#object-closedevent)
- [`Commit`](/en/graphql/reference/commits#object-commit)
- [`CommitCommentThread`](/en/graphql/reference/commits#object-commitcommentthread)
- [`CrossReferencedEvent`](/en/graphql/reference/issues#object-crossreferencedevent)
- [`DemilestonedEvent`](/en/graphql/reference/issues#object-demilestonedevent)
- [`DeployedEvent`](/en/graphql/reference/deployments#object-deployedevent)
- [`DeploymentEnvironmentChangedEvent`](/en/graphql/reference/deployments#object-deploymentenvironmentchangedevent)
- [`HeadRefDeletedEvent`](/en/graphql/reference/pulls#object-headrefdeletedevent)
- [`HeadRefForcePushedEvent`](/en/graphql/reference/pulls#object-headrefforcepushedevent)
- [`HeadRefRestoredEvent`](/en/graphql/reference/pulls#object-headrefrestoredevent)
- [`IssueComment`](/en/graphql/reference/issues#object-issuecomment)
- [`LabeledEvent`](/en/graphql/reference/issues#object-labeledevent)
- [`LockedEvent`](/en/graphql/reference/issues#object-lockedevent)
- [`MergedEvent`](/en/graphql/reference/pulls#object-mergedevent)
- [`MilestonedEvent`](/en/graphql/reference/issues#object-milestonedevent)
- [`PullRequestReview`](/en/graphql/reference/pulls#object-pullrequestreview)
- [`PullRequestReviewComment`](/en/graphql/reference/pulls#object-pullrequestreviewcomment)
- [`PullRequestReviewThread`](/en/graphql/reference/pulls#object-pullrequestreviewthread)
- [`ReferencedEvent`](/en/graphql/reference/issues#object-referencedevent)
- [`RenamedTitleEvent`](/en/graphql/reference/issues#object-renamedtitleevent)
- [`ReopenedEvent`](/en/graphql/reference/issues#object-reopenedevent)
- [`ReviewDismissedEvent`](/en/graphql/reference/pulls#object-reviewdismissedevent)
- [`ReviewRequestRemovedEvent`](/en/graphql/reference/pulls#object-reviewrequestremovedevent)
- [`ReviewRequestedEvent`](/en/graphql/reference/pulls#object-reviewrequestedevent)
- [`SubscribedEvent`](/en/graphql/reference/issues#object-subscribedevent)
- [`UnassignedEvent`](/en/graphql/reference/issues#object-unassignedevent)
- [`UnlabeledEvent`](/en/graphql/reference/issues#object-unlabeledevent)
- [`UnlockedEvent`](/en/graphql/reference/issues#object-unlockedevent)
- [`UnsubscribedEvent`](/en/graphql/reference/issues#object-unsubscribedevent)
- [`UserBlockedEvent`](/en/graphql/reference/users#object-userblockedevent)

### [PullRequestTimelineItems](#union-pullrequesttimelineitems)

Union

An item in a pull request timeline.

#### Possible types for `PullRequestTimelineItems`

- [`AddedToMergeQueueEvent`](/en/graphql/reference/pulls#object-addedtomergequeueevent)
- [`AddedToProjectEvent`](/en/graphql/reference/projects-classic#object-addedtoprojectevent)
- [`AddedToProjectV2Event`](/en/graphql/reference/projects#object-addedtoprojectv2event)
- [`AssignedEvent`](/en/graphql/reference/issues#object-assignedevent)
- [`AutoMergeDisabledEvent`](/en/graphql/reference/pulls#object-automergedisabledevent)
- [`AutoMergeEnabledEvent`](/en/graphql/reference/pulls#object-automergeenabledevent)
- [`AutoRebaseEnabledEvent`](/en/graphql/reference/pulls#object-autorebaseenabledevent)
- [`AutoSquashEnabledEvent`](/en/graphql/reference/pulls#object-autosquashenabledevent)
- [`AutomaticBaseChangeFailedEvent`](/en/graphql/reference/pulls#object-automaticbasechangefailedevent)
- [`AutomaticBaseChangeSucceededEvent`](/en/graphql/reference/pulls#object-automaticbasechangesucceededevent)
- [`BaseRefChangedEvent`](/en/graphql/reference/pulls#object-baserefchangedevent)
- [`BaseRefDeletedEvent`](/en/graphql/reference/pulls#object-baserefdeletedevent)
- [`BaseRefForcePushedEvent`](/en/graphql/reference/pulls#object-baserefforcepushedevent)
- [`BlockedByAddedEvent`](/en/graphql/reference/issues#object-blockedbyaddedevent)
- [`BlockedByRemovedEvent`](/en/graphql/reference/issues#object-blockedbyremovedevent)
- [`BlockingAddedEvent`](/en/graphql/reference/issues#object-blockingaddedevent)
- [`BlockingRemovedEvent`](/en/graphql/reference/issues#object-blockingremovedevent)
- [`ClosedEvent`](/en/graphql/reference/issues#object-closedevent)
- [`CommentDeletedEvent`](/en/graphql/reference/issues#object-commentdeletedevent)
- [`ConnectedEvent`](/en/graphql/reference/issues#object-connectedevent)
- [`ConvertToDraftEvent`](/en/graphql/reference/pulls#object-converttodraftevent)
- [`ConvertedFromDraftEvent`](/en/graphql/reference/pulls#object-convertedfromdraftevent)
- [`ConvertedNoteToIssueEvent`](/en/graphql/reference/issues#object-convertednotetoissueevent)
- [`ConvertedToDiscussionEvent`](/en/graphql/reference/issues#object-convertedtodiscussionevent)
- [`CrossReferencedEvent`](/en/graphql/reference/issues#object-crossreferencedevent)
- [`DemilestonedEvent`](/en/graphql/reference/issues#object-demilestonedevent)
- [`DeployedEvent`](/en/graphql/reference/deployments#object-deployedevent)
- [`DeploymentEnvironmentChangedEvent`](/en/graphql/reference/deployments#object-deploymentenvironmentchangedevent)
- [`DisconnectedEvent`](/en/graphql/reference/issues#object-disconnectedevent)
- [`HeadRefDeletedEvent`](/en/graphql/reference/pulls#object-headrefdeletedevent)
- [`HeadRefForcePushedEvent`](/en/graphql/reference/pulls#object-headrefforcepushedevent)
- [`HeadRefRestoredEvent`](/en/graphql/reference/pulls#object-headrefrestoredevent)
- [`IssueComment`](/en/graphql/reference/issues#object-issuecomment)
- [`IssueCommentPinnedEvent`](/en/graphql/reference/issues#object-issuecommentpinnedevent)
- [`IssueCommentUnpinnedEvent`](/en/graphql/reference/issues#object-issuecommentunpinnedevent)
- [`IssueFieldAddedEvent`](/en/graphql/reference/issues#object-issuefieldaddedevent)
- [`IssueFieldChangedEvent`](/en/graphql/reference/issues#object-issuefieldchangedevent)
- [`IssueFieldRemovedEvent`](/en/graphql/reference/issues#object-issuefieldremovedevent)
- [`IssueTypeAddedEvent`](/en/graphql/reference/issues#object-issuetypeaddedevent)
- [`IssueTypeChangedEvent`](/en/graphql/reference/issues#object-issuetypechangedevent)
- [`IssueTypeRemovedEvent`](/en/graphql/reference/issues#object-issuetyperemovedevent)
- [`LabeledEvent`](/en/graphql/reference/issues#object-labeledevent)
- [`LockedEvent`](/en/graphql/reference/issues#object-lockedevent)
- [`MarkedAsDuplicateEvent`](/en/graphql/reference/issues#object-markedasduplicateevent)
- [`MentionedEvent`](/en/graphql/reference/issues#object-mentionedevent)
- [`MergedEvent`](/en/graphql/reference/pulls#object-mergedevent)
- [`MilestonedEvent`](/en/graphql/reference/issues#object-milestonedevent)
- [`MovedColumnsInProjectEvent`](/en/graphql/reference/projects-classic#object-movedcolumnsinprojectevent)
- [`ParentIssueAddedEvent`](/en/graphql/reference/issues#object-parentissueaddedevent)
- [`ParentIssueRemovedEvent`](/en/graphql/reference/issues#object-parentissueremovedevent)
- [`PinnedEvent`](/en/graphql/reference/issues#object-pinnedevent)
- [`ProjectV2ItemStatusChangedEvent`](/en/graphql/reference/projects#object-projectv2itemstatuschangedevent)
- [`PullRequestCommit`](/en/graphql/reference/pulls#object-pullrequestcommit)
- [`PullRequestCommitCommentThread`](/en/graphql/reference/pulls#object-pullrequestcommitcommentthread)
- [`PullRequestReview`](/en/graphql/reference/pulls#object-pullrequestreview)
- [`PullRequestReviewThread`](/en/graphql/reference/pulls#object-pullrequestreviewthread)
- [`PullRequestRevisionMarker`](/en/graphql/reference/pulls#object-pullrequestrevisionmarker)
- [`ReadyForReviewEvent`](/en/graphql/reference/pulls#object-readyforreviewevent)
- [`ReferencedEvent`](/en/graphql/reference/issues#object-referencedevent)
- [`RemovedFromMergeQueueEvent`](/en/graphql/reference/pulls#object-removedfrommergequeueevent)
- [`RemovedFromProjectEvent`](/en/graphql/reference/projects-classic#object-removedfromprojectevent)
- [`RemovedFromProjectV2Event`](/en/graphql/reference/projects#object-removedfromprojectv2event)
- [`RenamedTitleEvent`](/en/graphql/reference/issues#object-renamedtitleevent)
- [`ReopenedEvent`](/en/graphql/reference/issues#object-reopenedevent)
- [`ReviewDismissedEvent`](/en/graphql/reference/pulls#object-reviewdismissedevent)
- [`ReviewRequestRemovedEvent`](/en/graphql/reference/pulls#object-reviewrequestremovedevent)
- [`ReviewRequestedEvent`](/en/graphql/reference/pulls#object-reviewrequestedevent)
- [`SubIssueAddedEvent`](/en/graphql/reference/issues#object-subissueaddedevent)
- [`SubIssueRemovedEvent`](/en/graphql/reference/issues#object-subissueremovedevent)
- [`SubscribedEvent`](/en/graphql/reference/issues#object-subscribedevent)
- [`TransferredEvent`](/en/graphql/reference/issues#object-transferredevent)
- [`UnassignedEvent`](/en/graphql/reference/issues#object-unassignedevent)
- [`UnlabeledEvent`](/en/graphql/reference/issues#object-unlabeledevent)
- [`UnlockedEvent`](/en/graphql/reference/issues#object-unlockedevent)
- [`UnmarkedAsDuplicateEvent`](/en/graphql/reference/issues#object-unmarkedasduplicateevent)
- [`UnpinnedEvent`](/en/graphql/reference/issues#object-unpinnedevent)
- [`UnsubscribedEvent`](/en/graphql/reference/issues#object-unsubscribedevent)
- [`UserBlockedEvent`](/en/graphql/reference/users#object-userblockedevent)

### [RequestedReviewer](#union-requestedreviewer)

Union

Types that can be requested reviewers.

#### Possible types for `RequestedReviewer`

- [`Bot`](/en/graphql/reference/apps#object-bot)
- [`EnterpriseTeam`](/en/graphql/reference/enterprise-admin#object-enterpriseteam)
- [`Mannequin`](/en/graphql/reference/migrations#object-mannequin)
- [`Team`](/en/graphql/reference/teams#object-team)
- [`User`](/en/graphql/reference/users#object-user)

## [Input objects](#input-objects)

### [AddPullRequestCreationCapBypassUsersInput](#input-object-addpullrequestcreationcapbypassusersinput)

Input object

Autogenerated input type of AddPullRequestCreationCapBypassUsers.

#### Input fields for `AddPullRequestCreationCapBypassUsersInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`repositoryId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the repository.  |

|

`userIds` (`[[ID!]!](/en/graphql/reference/other#scalar-id)`) |

The Node IDs of the users to add to the bypass list.  |

### [AddPullRequestReviewCommentInput](#input-object-addpullrequestreviewcommentinput)

Input object

Autogenerated input type of AddPullRequestReviewComment.

#### Input fields for `AddPullRequestReviewCommentInput`

| Name | Description  |

|

`body` (`[String](/en/graphql/reference/other#scalar-string)`) |

The text of the comment. This field is required

Upcoming Change on 2023-10-01 UTC Description: `body` will be removed. use addPullRequestReviewThread or addPullRequestReviewThreadReply instead Reason: We are deprecating the addPullRequestReviewComment mutation.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`commitOID` (`[GitObjectID](/en/graphql/reference/other#scalar-gitobjectid)`) |

The SHA of the commit to comment on.

Upcoming Change on 2023-10-01 UTC Description: `commitOID` will be removed. use addPullRequestReviewThread or addPullRequestReviewThreadReply instead Reason: We are deprecating the addPullRequestReviewComment mutation.  |

|

`inReplyTo` (`[ID](/en/graphql/reference/other#scalar-id)`) |

The comment id to reply to.

Upcoming Change on 2023-10-01 UTC Description: `inReplyTo` will be removed. use addPullRequestReviewThread or addPullRequestReviewThreadReply instead Reason: We are deprecating the addPullRequestReviewComment mutation.  |

|

`path` (`[String](/en/graphql/reference/other#scalar-string)`) |

The relative path of the file to comment on.

Upcoming Change on 2023-10-01 UTC Description: `path` will be removed. use addPullRequestReviewThread or addPullRequestReviewThreadReply instead Reason: We are deprecating the addPullRequestReviewComment mutation.  |

|

`position` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The line index in the diff to comment on.

Upcoming Change on 2023-10-01 UTC Description: `position` will be removed. use addPullRequestReviewThread or addPullRequestReviewThreadReply instead Reason: We are deprecating the addPullRequestReviewComment mutation.  |

|

`pullRequestId` (`[ID](/en/graphql/reference/other#scalar-id)`) |

The node ID of the pull request reviewing

Upcoming Change on 2023-10-01 UTC Description: `pullRequestId` will be removed. use addPullRequestReviewThread or addPullRequestReviewThreadReply instead Reason: We are deprecating the addPullRequestReviewComment mutation.  |

|

`pullRequestReviewId` (`[ID](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the review to modify.

Upcoming Change on 2023-10-01 UTC Description: `pullRequestReviewId` will be removed. use addPullRequestReviewThread or addPullRequestReviewThreadReply instead Reason: We are deprecating the addPullRequestReviewComment mutation.  |

### [AddPullRequestReviewInput](#input-object-addpullrequestreviewinput)

Input object

Autogenerated input type of AddPullRequestReview.

#### Input fields for `AddPullRequestReviewInput`

| Name | Description  |

|

`body` (`[String](/en/graphql/reference/other#scalar-string)`) |

The contents of the review body comment.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`comments` (`[[DraftPullRequestReviewComment]](/en/graphql/reference/pulls#input-object-draftpullrequestreviewcomment)`) |

The review line comments.

Upcoming Change on 2023-10-01 UTC Description: `comments` will be removed. use the `threads` argument instead Reason: We are deprecating comment fields that use diff-relative positioning.  |

|

`commitOID` (`[GitObjectID](/en/graphql/reference/other#scalar-gitobjectid)`) |

The commit OID the review pertains to.  |

|

`event` (`[PullRequestReviewEvent](/en/graphql/reference/pulls#enum-pullrequestreviewevent)`) |

The event to perform on the pull request review.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the pull request to modify.  |

|

`threads` (`[[DraftPullRequestReviewThread]](/en/graphql/reference/pulls#input-object-draftpullrequestreviewthread)`) |

The review line comment threads.  |

### [AddPullRequestReviewThreadInput](#input-object-addpullrequestreviewthreadinput)

Input object

Autogenerated input type of AddPullRequestReviewThread.

#### Input fields for `AddPullRequestReviewThreadInput`

| Name | Description  |

|

`body` (`[String!](/en/graphql/reference/other#scalar-string)`) |

Body of the thread's first comment.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`line` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The line of the blob to which the thread refers, required for line-level threads. The end of the line range for multi-line comments.  |

|

`path` (`[String](/en/graphql/reference/other#scalar-string)`) |

Path to the file being commented on.  |

|

`pullRequestId` (`[ID](/en/graphql/reference/other#scalar-id)`) |

The node ID of the pull request reviewing.  |

|

`pullRequestReviewId` (`[ID](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the review to modify.  |

|

`side` (`[DiffSide](/en/graphql/reference/pulls#enum-diffside)`) |

The side of the diff on which the line resides. For multi-line comments, this is the side for the end of the line range.  |

|

`startLine` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The first line of the range to which the comment refers.  |

|

`startSide` (`[DiffSide](/en/graphql/reference/pulls#enum-diffside)`) |

The side of the diff on which the start line resides.  |

|

`subjectType` (`[PullRequestReviewThreadSubjectType](/en/graphql/reference/pulls#enum-pullrequestreviewthreadsubjecttype)`) |

The level at which the comments in the corresponding thread are targeted, can be a diff line or a file.  |

### [AddPullRequestReviewThreadReplyInput](#input-object-addpullrequestreviewthreadreplyinput)

Input object

Autogenerated input type of AddPullRequestReviewThreadReply.

#### Input fields for `AddPullRequestReviewThreadReplyInput`

| Name | Description  |

|

`body` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The text of the reply.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestReviewId` (`[ID](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the pending review to which the reply will belong.  |

|

`pullRequestReviewThreadId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the thread to which this reply is being written.  |

### [ArchivePullRequestInput](#input-object-archivepullrequestinput)

Input object

Autogenerated input type of ArchivePullRequest.

#### Input fields for `ArchivePullRequestInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the pull request to archive.  |

### [ClosePullRequestInput](#input-object-closepullrequestinput)

Input object

Autogenerated input type of ClosePullRequest.

#### Input fields for `ClosePullRequestInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

ID of the pull request to be closed.  |

### [ConvertPullRequestToDraftInput](#input-object-convertpullrequesttodraftinput)

Input object

Autogenerated input type of ConvertPullRequestToDraft.

#### Input fields for `ConvertPullRequestToDraftInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

ID of the pull request to convert to draft.  |

### [CopilotCodeReviewParametersInput](#input-object-copilotcodereviewparametersinput)

Input object

Request Copilot code review for new pull requests automatically if the author has access to Copilot code review and their premium requests quota has not reached the limit.

#### Input fields for `CopilotCodeReviewParametersInput`

| Name | Description  |

|

`reviewDraftPullRequests` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`) |

Copilot automatically reviews draft pull requests before they are marked as ready for review.  |

|

`reviewOnPush` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`) |

Copilot automatically reviews each new push to the pull request.  |

### [CreatePullRequestInput](#input-object-createpullrequestinput)

Input object

Autogenerated input type of CreatePullRequest.

#### Input fields for `CreatePullRequestInput`

| Name | Description  |

|

`baseRefName` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The name of the branch you want your changes pulled into. This should be an existing branch on the current repository. You cannot update the base branch on a pull request to point to another repository.  |

|

`body` (`[String](/en/graphql/reference/other#scalar-string)`) |

The contents of the pull request.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`draft` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`) |

Indicates whether this pull request should be a draft.  |

|

`headRefName` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The name of the branch where your changes are implemented. For cross-repository pull requests in the same network, namespace `head_ref_name` with a user like this: `username:branch`.  |

|

`headRepositoryId` (`[ID](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the head repository.  |

|

`maintainerCanModify` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`) |

Indicates whether maintainers can modify the pull request.  |

|

`repositoryId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the repository.  |

|

`title` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The title of the pull request.  |

### [DeletePullRequestReviewCommentInput](#input-object-deletepullrequestreviewcommentinput)

Input object

Autogenerated input type of DeletePullRequestReviewComment.

#### Input fields for `DeletePullRequestReviewCommentInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The ID of the comment to delete.  |

### [DeletePullRequestReviewInput](#input-object-deletepullrequestreviewinput)

Input object

Autogenerated input type of DeletePullRequestReview.

#### Input fields for `DeletePullRequestReviewInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestReviewId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the pull request review to delete.  |

### [DequeuePullRequestInput](#input-object-dequeuepullrequestinput)

Input object

Autogenerated input type of DequeuePullRequest.

#### Input fields for `DequeuePullRequestInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The ID of the pull request to be dequeued.  |

### [DisablePullRequestAutoMergeInput](#input-object-disablepullrequestautomergeinput)

Input object

Autogenerated input type of DisablePullRequestAutoMerge.

#### Input fields for `DisablePullRequestAutoMergeInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

ID of the pull request to disable auto merge on.  |

### [DismissPullRequestReviewInput](#input-object-dismisspullrequestreviewinput)

Input object

Autogenerated input type of DismissPullRequestReview.

#### Input fields for `DismissPullRequestReviewInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`message` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The contents of the pull request review dismissal message.  |

|

`pullRequestReviewId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the pull request review to modify.  |

### [DraftPullRequestReviewComment](#input-object-draftpullrequestreviewcomment)

Input object

Specifies a review comment to be left with a Pull Request Review.

#### Input fields for `DraftPullRequestReviewComment`

| Name | Description  |

|

`body` (`[String!](/en/graphql/reference/other#scalar-string)`) |

Body of the comment to leave.  |

|

`path` (`[String!](/en/graphql/reference/other#scalar-string)`) |

Path to the file being commented on.  |

|

`position` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Position in the file to leave a comment on.  |

### [DraftPullRequestReviewThread](#input-object-draftpullrequestreviewthread)

Input object

Specifies a review comment thread to be left with a Pull Request Review.

#### Input fields for `DraftPullRequestReviewThread`

| Name | Description  |

|

`body` (`[String!](/en/graphql/reference/other#scalar-string)`) |

Body of the comment to leave.  |

|

`line` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The line of the blob to which the thread refers. The end of the line range for multi-line comments. Required if not using positioning.  |

|

`path` (`[String](/en/graphql/reference/other#scalar-string)`) |

Path to the file being commented on. Required if not using positioning.  |

|

`side` (`[DiffSide](/en/graphql/reference/pulls#enum-diffside)`) |

The side of the diff on which the line resides. For multi-line comments, this is the side for the end of the line range.  |

|

`startLine` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The first line of the range to which the comment refers.  |

|

`startSide` (`[DiffSide](/en/graphql/reference/pulls#enum-diffside)`) |

The side of the diff on which the start line resides.  |

### [EnablePullRequestAutoMergeInput](#input-object-enablepullrequestautomergeinput)

Input object

Autogenerated input type of EnablePullRequestAutoMerge.

#### Input fields for `EnablePullRequestAutoMergeInput`

| Name | Description  |

|

`authorEmail` (`[String](/en/graphql/reference/other#scalar-string)`) |

The email address to associate with this merge.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`commitBody` (`[String](/en/graphql/reference/other#scalar-string)`) |

Commit body to use for the commit when the PR is mergable; if omitted, a default message will be used. NOTE: when merging with a merge queue any input value for commit message is ignored.  |

|

`commitHeadline` (`[String](/en/graphql/reference/other#scalar-string)`) |

Commit headline to use for the commit when the PR is mergable; if omitted, a default message will be used. NOTE: when merging with a merge queue any input value for commit headline is ignored.  |

|

`expectedHeadOid` (`[GitObjectID](/en/graphql/reference/other#scalar-gitobjectid)`) |

The expected head OID of the pull request.  |

|

`mergeMethod` (`[PullRequestMergeMethod](/en/graphql/reference/pulls#enum-pullrequestmergemethod)`) |

The merge method to use. If omitted, defaults to `MERGE`. NOTE: when merging with a merge queue any input value for merge method is ignored.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

ID of the pull request to enable auto-merge on.  |

### [EnqueuePullRequestInput](#input-object-enqueuepullrequestinput)

Input object

Autogenerated input type of EnqueuePullRequest.

#### Input fields for `EnqueuePullRequestInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`expectedHeadOid` (`[GitObjectID](/en/graphql/reference/other#scalar-gitobjectid)`) |

The expected head OID of the pull request.  |

|

`jump` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`) |

Add the pull request to the front of the queue.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The ID of the pull request to enqueue.  |

### [MarkFileAsViewedInput](#input-object-markfileasviewedinput)

Input object

Autogenerated input type of MarkFileAsViewed.

#### Input fields for `MarkFileAsViewedInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`path` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The path of the file to mark as viewed.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the pull request.  |

### [MarkPullRequestReadyForReviewInput](#input-object-markpullrequestreadyforreviewinput)

Input object

Autogenerated input type of MarkPullRequestReadyForReview.

#### Input fields for `MarkPullRequestReadyForReviewInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

ID of the pull request to be marked as ready for review.  |

### [MergePullRequestInput](#input-object-mergepullrequestinput)

Input object

Autogenerated input type of MergePullRequest.

#### Input fields for `MergePullRequestInput`

| Name | Description  |

|

`authorEmail` (`[String](/en/graphql/reference/other#scalar-string)`) |

The email address to associate with this merge.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`commitBody` (`[String](/en/graphql/reference/other#scalar-string)`) |

Commit body to use for the merge commit; if omitted, a default message will be used.  |

|

`commitHeadline` (`[String](/en/graphql/reference/other#scalar-string)`) |

Commit headline to use for the merge commit; if omitted, a default message will be used.  |

|

`expectedHeadOid` (`[GitObjectID](/en/graphql/reference/other#scalar-gitobjectid)`) |

OID that the pull request head ref must match to allow merge; if omitted, no check is performed.  |

|

`mergeMethod` (`[PullRequestMergeMethod](/en/graphql/reference/pulls#enum-pullrequestmergemethod)`) |

The merge method to use. If omitted, defaults to 'MERGE'.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

ID of the pull request to be merged.  |

### [MergeQueueParametersInput](#input-object-mergequeueparametersinput)

Input object

Merges must be performed via a merge queue.

#### Input fields for `MergeQueueParametersInput`

| Name | Description  |

|

`checkResponseTimeoutMinutes` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Maximum time for a required status check to report a conclusion. After this much time has elapsed, checks that have not reported a conclusion will be assumed to have failed.  |

|

`groupingStrategy` (`[MergeQueueGroupingStrategy!](/en/graphql/reference/pulls#enum-mergequeuegroupingstrategy)`) |

When set to ALLGREEN, the merge commit created by merge queue for each PR in the group must pass all required checks to merge. When set to HEADGREEN, only the commit at the head of the merge group, i.e. the commit containing changes from all of the PRs in the group, must pass its required checks to merge.  |

|

`maxEntriesToBuild` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Limit the number of queued pull requests requesting checks and workflow runs at the same time.  |

|

`maxEntriesToMerge` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

The maximum number of PRs that will be merged together in a group.  |

|

`mergeMethod` (`[MergeQueueMergeMethod!](/en/graphql/reference/pulls#enum-mergequeuemergemethod)`) |

Method to use when merging changes from queued pull requests.  |

|

`minEntriesToMerge` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

The minimum number of PRs that will be merged together in a group.  |

|

`minEntriesToMergeWaitMinutes` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

The time merge queue should wait after the first PR is added to the queue for the minimum group size to be met. After this time has elapsed, the minimum group size will be ignored and a smaller group will be merged.  |

### [PullRequestOrder](#input-object-pullrequestorder)

Input object

Ways in which lists of issues can be ordered upon return.

#### Input fields for `PullRequestOrder`

| Name | Description  |

|

`direction` (`[OrderDirection!](/en/graphql/reference/meta#enum-orderdirection)`) |

The direction in which to order pull requests by the specified field.  |

|

`field` (`[PullRequestOrderField!](/en/graphql/reference/pulls#enum-pullrequestorderfield)`) |

The field in which to order pull requests by.  |

### [PullRequestParametersInput](#input-object-pullrequestparametersinput)

Input object

Require all commits be made to a non-target branch and submitted via a pull request before they can be merged.

#### Input fields for `PullRequestParametersInput`

| Name | Description  |

|

`allowedMergeMethods` (`[[PullRequestAllowedMergeMethods!]](/en/graphql/reference/pulls#enum-pullrequestallowedmergemethods)`) |

Array of allowed merge methods. Allowed values include `merge`, `squash`, and `rebase`. At least one option must be enabled.  |

|

`dismissStaleReviewsOnPush` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

New, reviewable commits pushed will dismiss previous pull request review approvals.  |

|

`requireCodeOwnerReview` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Require an approving review in pull requests that modify files that have a designated code owner.  |

|

`requireLastPushApproval` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Whether the most recent reviewable push must be approved by someone other than the person who pushed it.  |

|

`requiredApprovingReviewCount` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

The number of approving reviews that are required before a pull request can be merged.  |

|

`requiredReviewThreadResolution` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

All conversations on code must be resolved before a pull request can be merged.  |

|

`requiredReviewers` (`[[RequiredReviewerConfigurationInput!]](/en/graphql/reference/pulls#input-object-requiredreviewerconfigurationinput)`) |

This argument is in beta and subject to change. A collection of reviewers and associated file patterns. Each reviewer has a list of file patterns which determine the files that reviewer is required to review.  |

### [RemovePullRequestCreationCapBypassUsersInput](#input-object-removepullrequestcreationcapbypassusersinput)

Input object

Autogenerated input type of RemovePullRequestCreationCapBypassUsers.

#### Input fields for `RemovePullRequestCreationCapBypassUsersInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`repositoryId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the repository.  |

|

`userIds` (`[[ID!]!](/en/graphql/reference/other#scalar-id)`) |

The Node IDs of the users to remove from the bypass list.  |

### [ReopenPullRequestInput](#input-object-reopenpullrequestinput)

Input object

Autogenerated input type of ReopenPullRequest.

#### Input fields for `ReopenPullRequestInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

ID of the pull request to be reopened.  |

### [RequestReviewsByLoginInput](#input-object-requestreviewsbylogininput)

Input object

Autogenerated input type of RequestReviewsByLogin.

#### Input fields for `RequestReviewsByLoginInput`

| Name | Description  |

|

`botLogins` (`[[String!]](/en/graphql/reference/other#scalar-string)`) |

The logins of the bots to request reviews from, including the [bot] suffix (e.g., 'copilot-pull-request-reviewer[bot]').  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the pull request to modify.  |

|

`teamSlugs` (`[[String!]](/en/graphql/reference/other#scalar-string)`) |

The slugs of the teams to request reviews from (format: 'org/team-slug').  |

|

`union` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`) |

Add users to the set rather than replace.  |

|

`userLogins` (`[[String!]](/en/graphql/reference/other#scalar-string)`) |

The login strings of the users to request reviews from.  |

### [RequestReviewsInput](#input-object-requestreviewsinput)

Input object

Autogenerated input type of RequestReviews.

#### Input fields for `RequestReviewsInput`

| Name | Description  |

|

`botIds` (`[[ID!]](/en/graphql/reference/other#scalar-id)`) |

The Node IDs of the bot to request.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the pull request to modify.  |

|

`teamIds` (`[[ID!]](/en/graphql/reference/other#scalar-id)`) |

The Node IDs of the team to request.  |

|

`union` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`) |

Add users to the set rather than replace.  |

|

`userIds` (`[[ID!]](/en/graphql/reference/other#scalar-id)`) |

The Node IDs of the user to request.  |

### [RequiredReviewerConfigurationInput](#input-object-requiredreviewerconfigurationinput)

Input object

A reviewing team, and file patterns describing which files they must approve changes to.

#### Input fields for `RequiredReviewerConfigurationInput`

| Name | Description  |

|

`filePatterns` (`[[String!]!](/en/graphql/reference/other#scalar-string)`) |

Array of file patterns. Pull requests which change matching files must be approved by the specified team. File patterns use fnmatch syntax.  |

|

`minimumApprovals` (`[Int!](/en/graphql/reference/other#scalar-int)`) |

Minimum number of approvals required from the specified team. If set to zero, the team will be added to the pull request but approval is optional.  |

|

`reviewerId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

Node ID of the team which must review changes to matching files.  |

### [ResolveReviewThreadInput](#input-object-resolvereviewthreadinput)

Input object

Autogenerated input type of ResolveReviewThread.

#### Input fields for `ResolveReviewThreadInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`threadId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The ID of the thread to resolve.  |

### [RevertPullRequestInput](#input-object-revertpullrequestinput)

Input object

Autogenerated input type of RevertPullRequest.

#### Input fields for `RevertPullRequestInput`

| Name | Description  |

|

`body` (`[String](/en/graphql/reference/other#scalar-string)`) |

The description of the revert pull request.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`draft` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`) |

Indicates whether the revert pull request should be a draft.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The ID of the pull request to revert.  |

|

`title` (`[String](/en/graphql/reference/other#scalar-string)`) |

The title of the revert pull request.  |

### [SubmitPullRequestReviewInput](#input-object-submitpullrequestreviewinput)

Input object

Autogenerated input type of SubmitPullRequestReview.

#### Input fields for `SubmitPullRequestReviewInput`

| Name | Description  |

|

`body` (`[String](/en/graphql/reference/other#scalar-string)`) |

The text field to set on the Pull Request Review.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`event` (`[PullRequestReviewEvent!](/en/graphql/reference/pulls#enum-pullrequestreviewevent)`) |

The event to send to the Pull Request Review.  |

|

`pullRequestId` (`[ID](/en/graphql/reference/other#scalar-id)`) |

The Pull Request ID to submit any pending reviews.  |

|

`pullRequestReviewId` (`[ID](/en/graphql/reference/other#scalar-id)`) |

The Pull Request Review ID to submit.  |

### [UnarchivePullRequestInput](#input-object-unarchivepullrequestinput)

Input object

Autogenerated input type of UnarchivePullRequest.

#### Input fields for `UnarchivePullRequestInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the pull request to unarchive.  |

### [UnmarkFileAsViewedInput](#input-object-unmarkfileasviewedinput)

Input object

Autogenerated input type of UnmarkFileAsViewed.

#### Input fields for `UnmarkFileAsViewedInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`path` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The path of the file to mark as unviewed.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the pull request.  |

### [UnresolveReviewThreadInput](#input-object-unresolvereviewthreadinput)

Input object

Autogenerated input type of UnresolveReviewThread.

#### Input fields for `UnresolveReviewThreadInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`threadId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The ID of the thread to unresolve.  |

### [UpdatePullRequestBranchInput](#input-object-updatepullrequestbranchinput)

Input object

Autogenerated input type of UpdatePullRequestBranch.

#### Input fields for `UpdatePullRequestBranchInput`

| Name | Description  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`expectedHeadOid` (`[GitObjectID](/en/graphql/reference/other#scalar-gitobjectid)`) |

The head ref oid for the upstream branch.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the pull request.  |

|

`updateMethod` (`[PullRequestBranchUpdateMethod](/en/graphql/reference/pulls#enum-pullrequestbranchupdatemethod)`) |

The update branch method to use. If omitted, defaults to 'MERGE'.  |

### [UpdatePullRequestInput](#input-object-updatepullrequestinput)

Input object

Autogenerated input type of UpdatePullRequest.

#### Input fields for `UpdatePullRequestInput`

| Name | Description  |

|

`assigneeIds` (`[[ID!]](/en/graphql/reference/other#scalar-id)`) |

An array of Node IDs of users for this pull request.  |

|

`baseRefName` (`[String](/en/graphql/reference/other#scalar-string)`) |

The name of the branch you want your changes pulled into. This should be an existing branch on the current repository.  |

|

`body` (`[String](/en/graphql/reference/other#scalar-string)`) |

The contents of the pull request.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`labelIds` (`[[ID!]](/en/graphql/reference/other#scalar-id)`) |

An array of Node IDs of labels for this pull request.  |

|

`maintainerCanModify` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`) |

Indicates whether maintainers can modify the pull request.  |

|

`milestoneId` (`[ID](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the milestone for this pull request.  |

|

`projectIds` (`[[ID!]](/en/graphql/reference/other#scalar-id)`) |

An array of Node IDs for projects associated with this pull request.  |

|

`pullRequestId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the pull request.  |

|

`state` (`[PullRequestUpdateState](/en/graphql/reference/pulls#enum-pullrequestupdatestate)`) |

The target state of the pull request.  |

|

`title` (`[String](/en/graphql/reference/other#scalar-string)`) |

The title of the pull request.  |

### [UpdatePullRequestReviewCommentInput](#input-object-updatepullrequestreviewcommentinput)

Input object

Autogenerated input type of UpdatePullRequestReviewComment.

#### Input fields for `UpdatePullRequestReviewCommentInput`

| Name | Description  |

|

`body` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The text of the comment.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestReviewCommentId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the comment to modify.  |

### [UpdatePullRequestReviewInput](#input-object-updatepullrequestreviewinput)

Input object

Autogenerated input type of UpdatePullRequestReview.

#### Input fields for `UpdatePullRequestReviewInput`

| Name | Description  |

|

`body` (`[String!](/en/graphql/reference/other#scalar-string)`) |

The contents of the pull request review body.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`pullRequestReviewId` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the pull request review to modify.  |

### [UpdateTeamReviewAssignmentInput](#input-object-updateteamreviewassignmentinput)

Input object

Autogenerated input type of UpdateTeamReviewAssignment.

#### Input fields for `UpdateTeamReviewAssignmentInput`

| Name | Description  |

|

`algorithm` (`[TeamReviewAssignmentAlgorithm](/en/graphql/reference/teams#enum-teamreviewassignmentalgorithm)`) |

The algorithm to use for review assignment.  |

|

`clientMutationId` (`[String](/en/graphql/reference/other#scalar-string)`) |

A unique identifier for the client performing the mutation.  |

|

`countMembersAlreadyRequested` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`) |

Count any members whose review has already been requested against the required number of members assigned to review.  |

|

`enabled` (`[Boolean!](/en/graphql/reference/other#scalar-boolean)`) |

Turn on or off review assignment.  |

|

`excludedTeamMemberIds` (`[[ID!]](/en/graphql/reference/other#scalar-id)`) |

An array of team member IDs to exclude.  |

|

`id` (`[ID!](/en/graphql/reference/other#scalar-id)`) |

The Node ID of the team to update review assignments of.  |

|

`includeChildTeamMembers` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`) |

Include the members of any child teams when assigning.  |

|

`notifyTeam` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`) |

Notify the entire team of the PR if it is delegated.  |

|

`removeTeamRequest` (`[Boolean](/en/graphql/reference/other#scalar-boolean)`) |

Remove the team review request when assigning.  |

|

`teamMemberCount` (`[Int](/en/graphql/reference/other#scalar-int)`) |

The number of team members to assign.  |
