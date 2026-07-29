"""
The type of the issue relation.
"""
enum IssueRelationType {
  blocks
  duplicate
  related
  similar
}

"""
Input for creating a new project. A name and at least one team are required. All other fields are optional and will use defaults if not specified.
"""
input ProjectCreateInput {
  """
  The color of the project.
  """
  color: String
  """
  The project content as markdown.
  """
  content: String
  """
  The ID of the issue that was converted into this project.
  """
  convertedFromIssueId: String
  """
  The description for the project.
  """
  description: String
  """
  The icon of the project.
  """
  icon: String
  """
  The identifier in UUID v4 format. If none is provided, the backend will generate one.
  """
  id: String
  """
  The identifiers of the project labels associated with this project.
  """
  labelIds: [String!]
  """
  The ID of the last template applied to the project.
  """
  lastAppliedTemplateId: String
  """
  The identifier of the project lead.
  """
  leadId: String
  """
  The identifiers of the members of this project.
  """
  memberIds: [String!]
  """
  The name of the project.
  """
  name: String!
  """
  The priority of the project. 0 = No priority, 1 = Urgent, 2 = High, 3 = Medium, 4 = Low.
  """
  priority: Int
  """
  The sort order for the project within shared views, when ordered by priority.
  """
  prioritySortOrder: Float
  """
  The sort order for the project within shared views.
  """
  sortOrder: Float
  """
  The planned start date of the project.
  """
  startDate: TimelessDate
  """
  The resolution of the project's start date.
  """
  startDateResolution: DateResolutionType
  """
  The ID of the project status.
  """
  statusId: String
  """
  The planned target date of the project.
  """
  targetDate: TimelessDate
  """
  The resolution of the project's estimated completion date.
  """
  targetDateResolution: DateResolutionType
  """
  The identifiers of the teams this project is associated with.
  """
  teamIds: [String!]!
  """
  The ID of a project template to apply when creating the project. Overrides useDefaultTemplate if both are provided.
  """
  templateId: String
  """
  When set to true, the default project template of the first team provided will be applied. If templateId is provided, this will be ignored.
  """
  useDefaultTemplate: Boolean
}

"""
A state in a team's workflow, representing an issue status such as Triage, Backlog, Todo, In Progress, In Review, Done, or Canceled. Each team has its own set of workflow states that define the progression of issues through the team's process. Workflow states have a type that categorizes them (triage, backlog, unstarted, started, completed, canceled), a position that determines their display order, and a color for visual identification. States can be inherited from parent teams to sub-teams.
"""
type WorkflowState implements Node {
  """
  The time at which the entity was archived. Null if the entity has not been archived.
  """
  archivedAt: DateTime
  """
  The state's UI color as a HEX string.
  """
  color: String!
  """
  The time at which the entity was created.
  """
  createdAt: DateTime!
  """
  Description of the state.
  """
  description: String
  """
  The unique identifier of the entity.
  """
  id: ID!
  """
  The parent team's workflow state that this state was inherited from. Null if the state is not inherited from a parent team.
  """
  inheritedFrom: WorkflowState
  """
  Issues that currently have this workflow state. Returns a paginated and filterable list of issues.
  """
  issues(
    """
    A cursor to be used with first for forward pagination
    """
    after: String
    """
    A cursor to be used with last for backward pagination.
    """
    before: String
    """
    Filter returned issues.
    """
    filter: IssueFilter
    """
    The number of items to forward paginate (used with after). Defaults to 50.
    """
    first: Int
    """
    Should archived resources be included (default: false)
    """
    includeArchived: Boolean
    """
    The number of items to backward paginate (used with before). Defaults to 50.
    """
    last: Int
    """
    By which field should the pagination order by. Available options are createdAt (default) and updatedAt.
    """
    orderBy: PaginationOrderBy
  ): IssueConnection!
  """
  The state's human-readable name (e.g., 'In Progress', 'Done', 'Backlog').
  """
  name: String!
  """
  The position of the state in the team's workflow. States are displayed in ascending order of position within their type group.
  """
  position: Float!
  """
  The team that this workflow state belongs to. Each team has its own set of workflow states.
  """
  team: Team!
  """
  The type of the state. One of "triage", "backlog", "unstarted", "started", "completed", "canceled", "duplicate".
  """
  type: String!
  """
  The last time at which the entity was meaningfully updated. This is the same as the creation time if the entity hasn't
      been updated after creation.
  """
  updatedAt: DateTime!
}
