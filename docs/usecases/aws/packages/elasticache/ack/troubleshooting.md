---
title: Troubleshooting AWS ACK
---

## Delete default user before group is deleted

If a user named `default` is issued a `delete` command before the usergroup it belongs to has actually been deleted,
ACK returns an unrecoverable error, thus preventing the deletion process to complete successfully.

```yaml
  - message: "DefaultUserAssociatedToUserGroup: User is associated to user group(s)
      as a default user and can't be deleted.\n\tstatus code: 400, request id: 65cb3646-e20f-4ba6-96c2-bf38ce13f78e"
    status: "True"
    type: ACK.Terminal
```
