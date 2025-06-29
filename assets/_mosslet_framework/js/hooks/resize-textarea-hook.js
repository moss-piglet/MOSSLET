import autosize from "../lib/textarea-auto-resize";

/* Add this hook to textareas
  As a user types in a textarea, it expands or retracts automatically. eg:

  <.form_field
    type="textarea"
    form={f}
    field={:description}
    phx-hook="ResizeTextareaHook"
  />
*/
const ResizeTextareaHook = {
  mounted() {
    autosize(this.el);
  },
  updated() {
    autosize(this.el);
  },
};

export default ResizeTextareaHook;
