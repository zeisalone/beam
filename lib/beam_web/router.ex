defmodule BeamWeb.Router do
  use BeamWeb, :router

  import BeamWeb.UserAuth
  import BeamWeb.Plugs.AuthorizationPlugs

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BeamWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug :put_full_screen_flag
  end

  pipeline :redirect_if_authenticated do
    plug :redirect_if_user_is_authenticated
  end

  pipeline :ensure_authenticated do
    plug :require_authenticated_user
  end

  scope "/", BeamWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    get "/", PageController, :home
  end

  scope "/", BeamWeb do
    pipe_through [:browser, :ensure_authenticated]

    get "/tasks", TaskController, :index

    live_session :task_explanation,
      on_mount: [{BeamWeb.UserAuth, :mount_current_user}] do
      live "/tasks/:task_id", TaskExplanationLive
    end
  end

  scope "/tasks", BeamWeb do
    pipe_through [:browser, :ensure_authenticated]

    live_session :task_execution,
      on_mount: [{BeamWeb.UserAuth, :mount_current_user}] do
      live "/:task_id/training", DynamicTaskLive, :training
      live "/:task_id/test", DynamicTaskLive, :test
      live "/:task_id/config/edit", ExerciseConfig.ConfigEditLive, :edit
    end
  end

  scope "/results", BeamWeb.Results do
    pipe_through [:browser, :ensure_authenticated]

    live_session :results,
      on_mount: [{BeamWeb.UserAuth, :ensure_authenticated}] do
      live "/", ResultsMainLive
      live "/per_user", ResultsPerUserLive
      live "/aftertask", ResultsEndLive
      live "/per_exercise", ResultsPerExerciseLive
      live "/per_category", ResultsPerCategoryLive
      live "/general", ResultsGeneralStatsLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", BeamWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:beam, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BeamWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", BeamWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{BeamWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", BeamWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{BeamWeb.UserAuth, :ensure_authenticated}] do
      live "/welcome", WelcomePageLive, :show
      live "/users/profile", UserProfileLive, :show
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
      live "/dashboard/new_patient", UserPatientCreationLive, :new
      live "/dashboard/patient/:patient_id", PatientProfileLive, :show
      live "/notes/:patient_id", UserNotesLive, :show
      live "/dashboard", DashboardLive, :index
      live "/configurations", ExerciseConfig.EditionsReserveLive, :index
    end
  end

  scope "/", BeamWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{BeamWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  pipeline :admin do
    plug :ensure_admin
  end

  pipeline :terapeuta do
    plug :ensure_terapeuta
  end

  pipeline :paciente do
    plug :ensure_paciente
  end

  defp put_full_screen_flag(conn, _opts) do
    path = conn.request_path
    full_screen = String.contains?(path, "/training") or String.contains?(path, "/test")
    assign(conn, :full_screen?, full_screen)
  end
end
