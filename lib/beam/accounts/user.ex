defmodule Beam.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias Pbkdf2

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :confirmed_at, :utc_datetime
    field :name, :string
    field :type, :string
    field :profile_image, :string, default: "images/profile/profile.svg"

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :type, :profile_image])
    |> validate_required([:email, :name, :type, :profile_image])
    |> validate_inclusion(:type, ["Paciente", "Terapeuta", "Admin"],
      message: "Deve ser Paciente, Terapeuta, ou Admin"
    )
  end

  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :name, :type])
    |> validate_required([:email, :password, :name, :type])
    |> validate_email(opts)
    |> validate_password(opts)
    |> validate_inclusion(:type, ["Paciente", "Terapeuta", "Admin"],
      message: "Deve ser Paciente, Terapeuta, ou Admin"
    )
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "Must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 6, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Pbkdf2.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Beam.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  def valid_password?(%Beam.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Pbkdf2.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Pbkdf2.no_user_verify()
    false
  end

  @doc """
  Verifies is user is admin.
  """
  def admin?(%__MODULE__{type: "Admin"}), do: true
  def admin?(_), do: false

  @doc """
  Verifies is user is therapist.
  """
  def therapist?(%__MODULE__{type: "Terapeuta"}), do: true
  def therapist?(_), do: false

  @doc """
  Verifies is user is paciente.
  """
  def paciente?(%__MODULE__{type: "Paciente"}), do: true
  def paciente?(_), do: false

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    changeset = cast(changeset, %{current_password: password}, [:current_password])

    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
