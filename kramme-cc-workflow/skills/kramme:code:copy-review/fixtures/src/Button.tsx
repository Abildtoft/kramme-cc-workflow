import React from "react";

interface ButtonProps {
  onClick: () => void;
  disabled?: boolean;
  variant?: "primary" | "secondary" | "danger";
}

export function SubmitButton({ onClick, disabled }: ButtonProps) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className="btn btn-primary"
      title="Click to submit the button"
      aria-label="Submit button for form submission"
    >
      Submit Button
    </button>
  );
}

export function DeleteButton({ onClick, disabled }: ButtonProps) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className="btn btn-danger"
      title="Click this button to delete the item permanently"
      aria-label="Delete button to permanently delete the selected item"
    >
      Delete Item Button
    </button>
  );
}

export function SaveButton({ onClick, disabled }: ButtonProps) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className="btn btn-primary"
      title="Click to save your changes to the form"
      aria-label="Save button for saving all form changes"
    >
      Save Changes Button
    </button>
  );
}

export function CancelButton({ onClick }: ButtonProps) {
  return (
    <button
      onClick={onClick}
      className="btn btn-secondary"
      title="Click to cancel and go back to the previous page"
      aria-label="Cancel button to cancel the current operation and return"
    >
      Cancel Operation
    </button>
  );
}

export function LoadMoreButton({ onClick, disabled }: ButtonProps) {
  return (
    <div className="load-more-container">
      <p className="load-more-text">Click the button below to load more items</p>
      <button
        onClick={onClick}
        disabled={disabled}
        className="btn btn-secondary"
        title="Click to load more items into the list"
        aria-label="Load more button to load additional items into the current list view"
      >
        Load More Items
      </button>
      <span className="load-more-hint">
        Press the load more button to see additional results
      </span>
    </div>
  );
}
