// Status indicator hook for real-time status updates
const StatusIndicatorHook = {
  mounted() {
    // Handle real-time status updates without disrupting the timeline
    this.handleEvent(
      "update_user_status",
      ({ user_id, status, status_message }) => {
        console.log(status_message, "STATUS MESSAGE");
        console.log(status, "STATUS");
        // Find all posts by this user and update their status elements
        document
          .querySelectorAll(`[data-user-id="${user_id}"]`)
          .forEach((postElement) => {
            // Update status indicator dot classes
            const statusIndicator = postElement.querySelector(
              '[data-status-indicator="true"]'
            );
            if (statusIndicator) {
              // Remove all existing gradient classes and add the new ones
              const newClasses = this.getStatusDotClasses(status);

              // Remove existing gradient classes
              statusIndicator.classList.remove(
                // All possible existing status gradients
                ...this.getStatusDotClasses("online").split(" "),
                ...this.getStatusDotClasses("calm").split(" "),
                ...this.getStatusDotClasses("active").split(" "),
                ...this.getStatusDotClasses("busy").split(" "),
                ...this.getStatusDotClasses("away").split(" "),
                ...this.getStatusDotClasses("offline").split(" ")
              );

              // Add new gradient classes
              statusIndicator.classList.add(...newClasses.split(" "));
            }

            // Update status message content in status cards
            const statusMessageElements = postElement.querySelectorAll(
              '[data-status-message-content="true"]'
            );
            statusMessageElements.forEach((messageEl) => {
              if (status_message && status_message.trim() !== "") {
                messageEl.textContent = status_message;
                // Update styling for custom message
                messageEl.className =
                  "text-sm text-slate-600 dark:text-slate-300 leading-relaxed";
              } else {
                messageEl.textContent = this.getDefaultStatusMessage(status);
                // Update styling for default message
                messageEl.className =
                  "text-xs text-slate-500 dark:text-slate-400";
              }
            });
          });
      }
    );
  },

  // Helper function to get status dot classes based on status (matching Elixir timeline_status_dot_classes)
  getStatusDotClasses(status) {
    switch (status) {
      case "online":
        return "bg-gradient-to-br from-emerald-400 to-teal-500";
      case "calm":
        return "bg-gradient-to-br from-teal-400 to-emerald-500";
      case "active":
        return "bg-gradient-to-br from-blue-400 to-emerald-500";
      case "busy":
        return "bg-gradient-to-br from-rose-400 to-pink-500";
      case "away":
        return "bg-gradient-to-br from-amber-400 to-orange-500";
      case "offline":
      default:
        return "bg-gradient-to-br from-slate-400 to-gray-500";
    }
  },

  // Helper function to get default status messages
  getDefaultStatusMessage(status) {
    switch (status) {
      case "offline":
        return "Currently offline";
      case "calm":
      case "online":
        return "Available to chat";
      case "active":
        return "Active and engaged";
      case "busy":
        return "Please don't disturb";
      case "away":
        return "Away from keyboard";
      default:
        return "Status unknown";
    }
  },
};

export default StatusIndicatorHook;
