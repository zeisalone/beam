defmodule Beam.Repo.Migrations.CreateUsersAndRolesTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :utc_datetime

      add :name, :string
      add :type, :string
      add :profile_image, :string, default: "images/profile/profile.svg"
      add :custom_images, {:array, :string}, default: [], null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])

    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])

    create table(:therapists) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :therapist_id, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:therapists, [:therapist_id])

    create table(:patients) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :therapist_id,
          references(:therapists, column: :therapist_id, type: :string, on_delete: :delete_all),
          null: false

      add :patient_id, :string, null: false
      add :birth_date, :date, null: false, default: "1980-01-01"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:patients, [:patient_id])
  end
end
