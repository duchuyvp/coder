# Workspaces

A workspace is the environment that a developer works in. Developers in a team
each work from their own workspace and can use
[multiple IDEs](./workspace-access/README.md).

A developer creates a workspace from a
[shared template](../admin/templates/README.md). This lets an entire team work
in environments that are identically configured and provisioned with the same
resources.

## Creating workspaces

You can create a workspace in the UI. Log in to your Coder instance, go to the
**Templates** tab, find the template you need, and select **Create Workspace**.

![Creating a workspace in the UI](./images/creating-workspace-ui.png)

When you create a workspace, you will be prompted to give it a name. You might
also be prompted to set some parameters that the template provides.

You can manage your existing templates in the **Workspaces** tab.

You can also create a workspace from the command line:

Each Coder user has their own workspaces created from
[templates](./admin/templates/README.md):

```shell
# create a workspace from the template; specify any variables
coder create --template="<templateName>" <workspaceName>

# show the resources behind the workspace and how to connect
coder show <workspace-name>
```

## Workspace filtering

In the Coder UI, you can filter your workspaces using pre-defined filters or
Coder's filter query. Filters follow the pattern `[filter name]:[filter text]`
and multiple filters can be specified separated by a space i.e
`owner:me status:running`

The following filters are supported:

- `owner` - Represents the `username` of the owner. You can also use `me` as a
  convenient alias for the logged-in user, e.g., `owner:me`
- `name` - Name of the workspace.
- `template` - Name of the template.
- `status` - Indicates the status of the workspace, e.g, `status:failed` For a
  list of supported statuses, see
  [WorkspaceStatus documentation](https://pkg.go.dev/github.com/coder/coder/codersdk#WorkspaceStatus).
- `outdated` - Filters workspaces using an outdated template version, e.g,
  `outdated:true`
- `dormant` - Filters workspaces based on the dormant state, e.g `dormant:true`
- `has-agent` - Only applicable for workspaces in "start" transition. Stopped
  and deleted workspaces don't have agents. List of supported values
  `connecting|connected|timeout`, e.g, `has-agent:connecting`
- `id` - Workspace UUID

### Automatic updates

It can be tedious to manually update a workspace everytime an update is pushed
to a template. Users can choose to opt-in to automatic updates to update to the
active template version whenever the workspace is started.

Note: If a template is updated such that new parameter inputs are required from
the user, autostart will be disabled for the workspace until the user has
manually updated the workspace.

![Automatic Updates](./images/workspace-automatic-updates.png)

## Starting and stopping workspaces

By default, you manually start and stop workspaces as you need. You can also
schedule a workspace to start and stop automatically.

To set a workspace's schedule, go to the workspace, then **Settings** >
**Schedule**.

![Scheduling UI](./images/schedule.png)

Coder might also stop a workspace automatically if there is a
[template update](./admin/templates/README.md#Start/stop) available.

Learn more about [workspace lifecycle](../admin/workspaces/lifecycle.md) and our
[scheduling features](./workspace-scheduling.md).

## Workspace resources

Workspaces in Coder are started and stopped, often based on whether there was
any activity or if there was a [template update](./admin/templates/README.md)
available.

Resources are often destroyed and re-created when a workspace is restarted,
though the exact behavior depends on the template. For more information, see
[Resource Persistence](./admin/templates/extending-templates/resource-persistence.md).