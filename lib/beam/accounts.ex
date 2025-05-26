defmodule Beam.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Beam.Repo
  alias Pbkdf2
  alias Beam.Accounts.{User, UserToken, UserNotifier, Therapist, Patient, Note}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def verify_user_type(user_id, therapist_id \\ nil, birth_date \\ nil, gender \\ "Masculino", education_level \\ "Pré-Primaria") do
    Repo.transaction(fn ->
      user = Repo.get!(User, user_id)

      case user.type do
        "Terapeuta" ->
          therapist_id = UUID.uuid4()

          case Repo.insert(
                 %Therapist{}
                 |> Therapist.changeset(%{user_id: user.id, therapist_id: therapist_id})
               ) do
            {:ok, _therapist} -> :ok
            {:error, reason} -> Repo.rollback(reason)
          end

        "Paciente" when not is_nil(therapist_id) ->
          patient_id = UUID.uuid4()
          case Repo.get_by(Therapist, therapist_id: therapist_id) do
            nil ->
              Repo.rollback("Therapist with ID #{therapist_id} not found.")

            therapist ->
              case Repo.insert(%Patient{}
                |> Patient.changeset(%{
                  user_id: user.id,
                  patient_id: patient_id,
                  therapist_id: therapist.therapist_id,
                  birth_date: birth_date,
                  gender: gender,
                  education_level: education_level
                })) do
                {:ok, _} -> :ok
                {:error, reason} -> Repo.rollback(reason)
              end
          end

        "Paciente" ->
          Repo.rollback("Therapist ID is required for patients.")

        _ -> :ok
      end
    end)
    |> case do
      {:ok, :ok} -> {:ok, :ok}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm_email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  def change_user_profile(user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  def update_user_profile(user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def list_pacientes do
    Repo.all(
      from p in Patient,
        join: u in assoc(p, :user),
        join: d in assoc(p, :therapist),
        join: du in assoc(d, :user),
        preload: [user: u, therapist: {d, user: du}]
    )
  end

  def list_patients_for_therapist(user_id) do
    case Repo.get_by(Beam.Accounts.Therapist, user_id: user_id) do
      nil ->
        []

      therapist ->
        Repo.all(
          from p in Beam.Accounts.Patient,
            where: p.therapist_id == ^therapist.therapist_id,
            join: u in assoc(p, :user),
            preload: [user: u]
        )
    end
  end

  def update_patient_gender(user_id, gender) do
    case Repo.get_by(Beam.Accounts.Patient, user_id: user_id) do
      nil -> {:error, :not_found}
      patient ->
        patient
        |> Ecto.Changeset.change(gender: gender)
        |> Repo.update()
    end
  end

  def update_patient_education(user_id, education) do
    case Repo.get_by(Beam.Accounts.Patient, user_id: user_id) do
      nil -> {:error, :not_found}
      patient ->
        patient
        |> Ecto.Changeset.change(education_level: education)
        |> Repo.update()
    end
  end

  def get_patient_gender(user_id) do
    case Repo.get_by(Beam.Accounts.Patient, user_id: user_id) do
      nil -> nil
      patient -> patient.gender
    end
  end

  def get_patient_education(user_id) do
    case Repo.get_by(Beam.Accounts.Patient, user_id: user_id) do
      nil -> nil
      patient -> patient.education_level
    end
  end

  def update_patient_info(user_id, attrs) do
    with %Patient{} = patient <- Repo.get_by(Patient, user_id: user_id) do
      patient
      |> Ecto.Changeset.change(attrs)
      |> Repo.update()
    end
  end


  def list_terapeutas do
    Repo.all(
      from d in Therapist,
        join: u in assoc(d, :user),
        preload: [user: u]
    )
  end

  def get_patient_with_user(user_id) do
    Repo.one(
      from p in Patient,
        where: p.user_id == ^user_id,
        join: u in assoc(p, :user),
        preload: [user: u]
    )
  end

  def get_user_id_by_patient_id(patient_id) do
    Repo.one(
      from p in Patient,
        where: p.id == ^patient_id,
        select: p.user_id
    )
  end

  def create_note(attrs) do
    %Note{}
    |> Note.changeset(attrs)
    |> Repo.insert()
  end

  def delete_note(note_id) do
    note = Repo.get(Note, note_id)

    if note do
      Repo.delete(note)
    else
      {:error, "Nota não encontrada"}
    end
  end

  def list_notes_for_patient(patient_id) do
    Repo.all(
      from n in Note,
        where: n.patient_id == ^patient_id,
        order_by: [desc: n.inserted_at],
        preload: [:therapist]
    )
  end

  def get_note!(id), do: Repo.get!(Note, id)

  def get_therapist_by_user_id(user_id) do
    Repo.get_by(Therapist, user_id: user_id)
  end

  def get_patient_age(user_id) do
    case Repo.get_by(Patient, user_id: user_id) do
      nil -> nil
      %Patient{birth_date: birth_date} ->
        calculate_age(birth_date)
    end
  end

  def get_patient_email(user_id) do
    case Repo.get(User, user_id) do
      nil -> nil
      %User{email: email} -> email
    end
  end

  defp calculate_age(birth_date) do
    today = Date.utc_today()
    years = today.year - birth_date.year
    if Date.compare(Date.new!(today.year, birth_date.month, birth_date.day), today) == :gt do
      years - 1
    else
      years
    end
  end

  def get_patient_birth_date(user_id) do
    case Repo.get_by(Patient, user_id: user_id) do
      nil -> nil
      patient -> patient.birth_date
    end
  end

  def update_patient_birth_date(user_id, new_birth_date) do
    case Repo.get_by(Patient, user_id: user_id) do
      nil -> {:error, :not_found}
      patient ->
        patient
        |> Ecto.Changeset.change(birth_date: new_birth_date)
        |> Repo.update()
    end
  end

  def average_patient_age do
    from(p in Patient,
      where: not is_nil(p.birth_date),
      select: avg(fragment("DATE_PART('year', AGE(current_date, ?))", p.birth_date))
    )
    |> Repo.one()
  end

  def average_patient_age_for_therapist(therapist_user_id) do
    from(p in Patient,
      join: t in assoc(p, :therapist),
      where: not is_nil(p.birth_date) and t.user_id == ^therapist_user_id,
      select: avg(fragment("DATE_PART('year', AGE(current_date, ?))", p.birth_date))
    )
    |> Repo.one()
  end

  def age_distribution_all_patients do
    query =
      from p in Beam.Accounts.Patient,
        where: not is_nil(p.birth_date),
        select: fragment("CAST(FLOOR(DATE_PART('year', AGE(current_date, ?))) AS INTEGER)", p.birth_date)

    Repo.all(query)
    |> group_ages()
  end

  def age_distribution_for_therapist(therapist_user_id) do
    query =
      from p in Beam.Accounts.Patient,
        join: t in Beam.Accounts.Therapist,
        on: p.therapist_id == t.therapist_id,
        where: t.user_id == ^therapist_user_id and not is_nil(p.birth_date),
        select: fragment("CAST(FLOOR(DATE_PART('year', AGE(current_date, ?))) AS INTEGER)", p.birth_date)

    Repo.all(query)
    |> group_ages()
  end

  defp group_ages(ages) do
    ranges = [
      {"0-6", 0..6},
      {"7-12", 7..12},
      {"13-18", 13..18},
      {"19-29", 19..29},
      {"30-44", 30..44},
      {"45-59", 45..59},
      {"60+", 60..150}
    ]

    total = length(ages)

    Enum.map(ranges, fn {label, range} ->
      count = Enum.count(ages, &(&1 in range))
      percent = if total > 0, do: Float.round(count * 100 / total, 1), else: 0.0
      %{label: label, percent: percent}
    end)
  end
end
