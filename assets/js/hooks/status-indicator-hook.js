// Status indicator hook for real-time status updates
const StatusIndicatorHook = {
  mounted() {
    // Handle real-time status updates without disrupting the timeline
    this.handleEvent(
      "update_user_status",
      ({ user_id, status, status_message, visible = true }) => {
        console.log(status_message, "STATUS MESSAGE");
        console.log(status, "STATUS");
        console.log(visible, "STATUS VISIBLE");
        
        // Find all status elements for this user (both in posts and UI elements)
        // Method 1: Find posts by data-user-id
        const postElements = document.querySelectorAll(`[data-user-id="${user_id}"]`);
        
        // Method 2: Find status indicators by container ID pattern
        const statusContainers = document.querySelectorAll(`#status-indicator-container-${user_id}`);
        
        // If status is not visible, hide all status elements and exit early
        if (!visible) {
          console.log('Status not visible - hiding all elements');
          
          // Hide status indicators in posts
          postElements.forEach((postElement) => {
            const statusIndicator = postElement.querySelector('[data-status-indicator="true"]');
            if (statusIndicator) {
              statusIndicator.style.display = 'none';
            }
            
            const statusCards = postElement.querySelectorAll('[data-status-message="true"]');
            statusCards.forEach((card) => {
              card.style.display = 'none';
            });
          });
          
          // Hide status indicators in UI containers
          statusContainers.forEach((container) => {
            const statusIndicator = container.querySelector('[data-status-indicator="true"]');
            if (statusIndicator) {
              statusIndicator.style.display = 'none';
            }
          });
          
          return; // Exit early - don't process any status updates
        }
        
        console.log('Status visible - showing and updating elements');
        
        // Status is visible - proceed with normal updates for posts
        postElements.forEach((postElement) => {
          const statusIndicator = postElement.querySelector('[data-status-indicator="true"]');
          if (statusIndicator) {
            statusIndicator.style.display = ''; // Show the indicator
            
            const newClasses = this.getStatusDotClasses(status);
            statusIndicator.classList.remove(
              ...this.getStatusDotClasses("online").split(" "),
              ...this.getStatusDotClasses("calm").split(" "),
              ...this.getStatusDotClasses("active").split(" "),
              ...this.getStatusDotClasses("busy").split(" "),
              ...this.getStatusDotClasses("away").split(" "),
              ...this.getStatusDotClasses("offline").split(" ")
            );
            statusIndicator.classList.add(...newClasses.split(" "));
            
            const pulseElement = statusIndicator.querySelector(".animate-ping");
            if (pulseElement) {
              pulseElement.classList.remove(
                ...this.getStatusPulseClasses("online").split(" "),
                ...this.getStatusPulseClasses("calm").split(" "),
                ...this.getStatusPulseClasses("active").split(" "),
                ...this.getStatusPulseClasses("busy").split(" "),
                ...this.getStatusPulseClasses("away").split(" "),
                ...this.getStatusPulseClasses("offline").split(" ")
              );
              
              const newPulseClasses = this.getStatusPulseClasses(status);
              if (newPulseClasses) {
                pulseElement.classList.add(...newPulseClasses.split(" "));
              }
            }
          }
          
          const statusCards = postElement.querySelectorAll('[data-status-message="true"]');
          statusCards.forEach((card) => {
            card.style.display = ''; // Show the card
          });
          
          const statusMessageElements = postElement.querySelectorAll('[data-status-message-content="true"]');
          statusMessageElements.forEach((messageEl) => {
            if (status_message && status_message.trim() !== "") {
              messageEl.textContent = status_message;
              messageEl.className = "text-sm text-slate-600 dark:text-slate-300 leading-relaxed";
            } else {
              messageEl.textContent = this.getDefaultStatusMessage(status);
              messageEl.className = "text-xs text-slate-500 dark:text-slate-400";
            }
          });
          
          const statusHeaderElements = postElement.querySelectorAll('[data-status-header="true"]');
          statusHeaderElements.forEach((headerEl) => {
            headerEl.textContent = this.getStatusDisplayName(status);
          });
          
          const statusDotElements = postElement.querySelectorAll('[data-status-dot="true"]');
          statusDotElements.forEach((dotEl) => {
            dotEl.classList.remove(
              ...this.getStatusDotClasses("online").split(" "),
              ...this.getStatusDotClasses("calm").split(" "),
              ...this.getStatusDotClasses("active").split(" "),
              ...this.getStatusDotClasses("busy").split(" "),
              ...this.getStatusDotClasses("away").split(" "),
              ...this.getStatusDotClasses("offline").split(" ")
            );
            
            const newDotClasses = this.getStatusDotClasses(status);
            dotEl.classList.add(...newDotClasses.split(" "));
          });
        });
        
        // Update status indicators in UI containers
        statusContainers.forEach((container) => {
          const statusIndicator = container.querySelector('[data-status-indicator="true"]');
          if (statusIndicator) {
            statusIndicator.style.display = ''; // Show the indicator
            
            const newClasses = this.getStatusDotClasses(status);
            statusIndicator.classList.remove(
              ...this.getStatusDotClasses("online").split(" "),
              ...this.getStatusDotClasses("calm").split(" "),
              ...this.getStatusDotClasses("active").split(" "),
              ...this.getStatusDotClasses("busy").split(" "),
              ...this.getStatusDotClasses("away").split(" "),
              ...this.getStatusDotClasses("offline").split(" ")
            );
            statusIndicator.classList.add(...newClasses.split(" "));
            
            const pulseElement = statusIndicator.querySelector(".animate-ping");
            if (pulseElement) {
              pulseElement.classList.remove(
                ...this.getStatusPulseClasses("online").split(" "),
                ...this.getStatusPulseClasses("calm").split(" "),
                ...this.getStatusPulseClasses("active").split(" "),
                ...this.getStatusPulseClasses("busy").split(" "),
                ...this.getStatusPulseClasses("away").split(" "),
                ...this.getStatusPulseClasses("offline").split(" ")
              );
              
              const newPulseClasses = this.getStatusPulseClasses(status);
              if (newPulseClasses) {
                pulseElement.classList.add(...newPulseClasses.split(" "));
              }
            }
          }
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
  
  // Helper function to get status pulse classes (matching Elixir timeline_status_ping_classes)
  getStatusPulseClasses(status) {
    switch (status) {
      case "online":
        return "bg-emerald-400";
      case "calm":
        return "bg-teal-400";
      case "active":
        return "bg-blue-400";
      case "busy":
        return "bg-rose-400";
      case "away":
        return "bg-amber-400";
      case "offline":
      default:
        return "bg-slate-400";
    }
  },
  
  // Helper function to get status display names
  getStatusDisplayName(status) {
    switch (status) {
      case "online":
        return "Online";
      case "calm":
        return "Calm";
      case "active":
        return "Active";
      case "busy":
        return "Busy";
      case "away":
        return "Away";
      case "offline":
      default:
        return "Offline";
    }
  },

  // Helper function to get default status messages
  getDefaultStatusMessage(status) {
    switch (status) {
      case "offline":
        return "Taking a peaceful break";
      case "calm":
      case "online":
        return "Mindfully connected";
      case "active":
        return "Active and engaged";
      case "busy":
        return "Focused and productive";
      case "away":
        return "Away for a while";
      default:
        return "Status unknown";
    }
  },
};

export default StatusIndicatorHook;
