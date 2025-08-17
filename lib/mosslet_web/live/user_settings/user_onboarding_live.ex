defmodule MossletWeb.UserOnboardingLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts

  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(user_return_to: Map.get(params, "user_return_to", nil))
      |> assign(:name, nil)
      |> assign_form(Accounts.change_user_onboarding(socket.assigns.current_user))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-10 overflow-y-auto bg-background-100 dark:bg-gray-900">
      <div class="flex items-end justify-center min-h-screen px-4 pt-4 pb-20 text-center sm:block sm:p-0">
        <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">
          &#8203;
        </span>
        <div
          class="inline-block px-4 pt-5 pb-4 overflow-hidden text-left align-bottom transition-all transform bg-background-50 dark:bg-gray-800 rounded-lg shadow-xl dark:shadow-emerald-500/50 sm:my-8 sm:align-middle sm:max-w-2xl sm:w-full sm:p-6"
          role="dialog"
          aria-modal="true"
          aria-labelledby="modal-headline"
        >
          <div>
            <div class="flex items-center justify-center w-12 h-12 mx-auto text-2xl bg-green-100 rounded-full dark:bg-green-800">
              👋
            </div>
            <div class="mt-3 text-center sm:mt-5">
              <h3
                class="text-base/7 font-semibold text-emerald-600 dark:text-emerald-500"
                id="modal-headline"
              >
                {gettext("Welcome to Mosslet")}
              </h3>

              <div class="bg-background-50 dark:bg-gray-800">
                <div class="mx-auto max-w-7xl px-6 lg:px-8">
                  <div class="mx-auto max-w-5xl lg:max-w-none">
                    <div class="text-center">
                      <h2 class="text-5xl font-bold tracking-tight text-balance sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                        A growing movement
                      </h2>
                      <p class="mt-4 text-lg/8 text-gray-600 dark:text-gray-400">
                        Every day, people use Mosslet to take back control of their data and privacy online. We are committed to providing a secure, transparent, and user-friendly platform that empowers you to connect with others while keeping your personal information safe.
                      </p>
                    </div>
                    <div class="mt-6 sm:mt-10 mx-auto max-w-2xl lg:mx-0 lg:max-w-none">
                      <h1 class="mt-2 text-left text-2xl font-bold tracking-tight text-balance sm:text-3xl lg:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                        It's important you are here
                      </h1>
                      <div class="mt-6 grid max-w-xl grid-cols-1 gap-8 text-base/7 text-left text-gray-700 dark:text-gray-300 lg:max-w-none">
                        <div>
                          <p>
                            We live in a new ecomonic era called surveillance capitalism, "<.link
                              class="underline text-emerald-600 dark:text-emerald-500 hover:text-emerald-400 dark:hover:text-emerald-300"
                              navigate="https://shoshanazuboff.com/book/shoshana/"
                              target="_blank"
                              rel="noopener"
                            >where private human experience is secretly invaded, extracted as data, and exploited for hidden processes of manufacturing, prediction, and sales</.link>".
                          </p>
                          <p class="mt-8">
                            The easiest way to think about it is to compare how capitalism took nature (like forests, rivers, and minerals) and turned them into things that can be bought and sold. Surveillance capitalism does the same with our humanity (like our thoughts, feelings, and behaviors).
                          </p>
                          <p class="mt-8">
                            Here are some of the numbers that show how much data Facebook (Meta) gobbles up and secretly uses, just beyond our awareness (<.link
                              class="underline text-emerald-600 dark:text-emerald-500 hover:text-emerald-400 dark:hover:text-emerald-300"
                              navigate="https://www.clrn.org/how-much-data-does-facebook-take/"
                              target="_blank"
                              rel="noopener"
                            >clrn</.link>, <.link
                              class="underline text-emerald-600 dark:text-emerald-500 hover:text-emerald-400 dark:hover:text-emerald-300"
                              navigate="https://themarkup.org/privacy/2024/01/17/each-facebook-user-is-monitored-by-thousands-of-companies-study-indicates"
                              target="_blank"
                              rel="noopener"
                            >markup</.link>):
                          </p>
                        </div>
                      </div>
                    </div>
                    <dl class="mt-16 grid grid-cols-1 gap-0.5 overflow-hidden rounded-2xl text-center sm:grid-cols-2 lg:grid-cols-3">
                      <div class="flex flex-col bg-background-400/5 p-8">
                        <dt class="text-sm/6 font-semibold text-gray-600 dark:text-gray-400">
                          Terabytes of user data Facebook collects daily
                        </dt>
                        <dd class="order-first text-3xl font-semibold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                          450+
                        </dd>
                      </div>

                      <div class="flex flex-col bg-background-400/5 p-8">
                        <dt class="text-sm/6 font-semibold text-gray-600 dark:text-gray-400">
                          Companies giving user data to Facebook
                        </dt>
                        <dd class="order-first text-3xl font-semibold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                          186,892+
                        </dd>
                      </div>
                      <div class="flex flex-col bg-background-400/5 p-8">
                        <dt class="text-sm/6 font-semibold text-gray-600 dark:text-gray-400">
                          Companies sharing data on each user
                        </dt>
                        <dd class="order-first text-3xl font-semibold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                          2,230+
                        </dd>
                      </div>
                    </dl>
                    <div class="mt-6 sm:mt-10 mx-auto max-w-2xl lg:mx-0 lg:max-w-none">
                      <h1 class="mt-2 text-left text-2xl font-bold tracking-tight text-balance sm:text-3xl lg:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                        Next steps
                      </h1>
                      <div class="mt-6 grid max-w-xl grid-cols-1 gap-8 text-base/7 text-left text-gray-700 dark:text-gray-300 lg:max-w-none">
                        <div>
                          <p>
                            Welcome! By choosing Mosslet, you have taken an important step toward securing your privacy and dignity online.
                          </p>
                          <p class="mt-8">
                            After you complete this onboarding, you will be redirected to our secure payment portal to make a one-time payment for lifetime access to our service. This payment is not a subscription, and you will never be charged again. Your payment is vital for us to maintain the platform and continue to provide you with a secure and private service.
                          </p>
                          <p class="mt-8">
                            Thank you for joining the growing movement supporting simple and ethical software choices. We hope we'll earn your trust and look forward to providing you with a simple, ethical, and more human experience.
                          </p>
                        </div>
                      </div>

                      <div class="bg-background-100 dark:bg-gray-800 rounded-md p-4 text-left mt-5 sm:mt-6">
                        <.form id="update_profile_form" for={@form} phx-submit="submit">
                          <.field
                            field={@form[:name]}
                            value={@name || @form[:name].value}
                            label={gettext("What is your name?")}
                            placeholder={gettext("eg. Isabella")}
                            autocomplete="off"
                            required
                            help_text="Your name is kept private to you and who you wish to share it with."
                          />

                          <.field
                            type="checkbox"
                            field={@form[:is_subscribed_to_marketing_notifications]}
                            label={gettext("Allow in-app notifications (like announcements)")}
                          />

                          <div class="flex items-center justify-between">
                            <.link class="text-sm underline" href={~p"/auth/sign_out"} method="delete">
                              {gettext("Sign out")}
                            </.link>
                            <.button class="rounded-full">{gettext("Submit")}</.button>
                          </div>
                        </.form>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("submit", %{"user" => user_params}, socket) do
    user_params = Map.put(user_params, "is_onboarded?", true)
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    case Accounts.update_user_onboarding_profile(current_user, user_params,
           change_name: true,
           key: key,
           user: current_user
         ) do
      {:ok, updated_user} ->
        Accounts.user_lifecycle_action("after_update_profile", updated_user)

        socket =
          socket
          |> put_flash(:success, gettext("You have been onboarded successfully!"))
          |> push_navigate(to: ~p"/app/subscribe")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> assign(:name, changeset.changes[:name_hash])
          |> assign_form(changeset)

        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
