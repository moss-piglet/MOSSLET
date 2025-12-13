defmodule MossletWeb.AuthRoutes do
  @moduledoc false
  defmacro __using__(_) do
    quote do
      scope "/auth", MossletWeb do
        pipe_through [:browser]

        delete "/sign_out", UserSessionController, :delete

        live_session :current_user,
          on_mount: [
            {MossletWeb.UserOnMountHooks, :maybe_assign_user}
          ] do
          live "/confirm/:token", UserConfirmationLive, :edit
          live "/confirm", UserConfirmationInstructionsLive, :new
          live "/reset-password/:token", UserResetPasswordLive, :edit
          get "/unlock", UnlockSessionController, :new
          post "/unlock", UnlockSessionController, :create
        end
      end

      scope "/auth", MossletWeb do
        pipe_through [:browser, :redirect_if_user_is_authenticated]

        live_session :redirect_if_user_is_authenticated,
          on_mount: [
            {MossletWeb.UserOnMountHooks, :redirect_if_user_is_authenticated}
          ] do
          live "/register", UserRegistrationLive, :new
          live "/sign_in", UserLoginLive, :new

          live "/reset-password", UserForgotPasswordLive, :new
        end

        put "/sign_in", UserSessionController, :create
        post "/sign_in", UserSessionController, :create
      end
    end
  end
end
