# Column Management

- `COL-001`: Users can create a column with a non-empty title.
- `COL-002`: Users can rename a column with a non-empty title.
- `COL-003`: Users can delete a column.
- `COL-004`: Column order is stable and reindexed after structural updates.

## Delete Column Confirmation

- `COL-DEL-001`: Deleting a column requires explicit user confirmation.
- `COL-DEL-002`: The confirmation dialog includes the column title.
- `COL-DEL-003`: Canceling the dialog performs no delete operation.
- `COL-DEL-004`: Confirming the dialog executes the delete request.

## Delete Column Rule

- `COL-RULE-001`: A column that still contains todos must not be deletable.
- `COL-RULE-002`: The API returns conflict (`409`) for this case.
- `COL-RULE-003`: The UI surfaces the failure status to the user.
