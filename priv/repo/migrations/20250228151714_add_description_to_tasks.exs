defmodule Beam.Repo.Migrations.AddDescriptionToTasks do
  use Ecto.Migration

  def up do
    alter table(:tasks) do
      add :description, :text
    end

    flush()

    execute("""
    INSERT INTO tasks (name, type, description, inserted_at, updated_at)
    VALUES
      ('Matemática', 'math_operation', 'Esta tarefa avalia a sua capacidade de resolver operações matemáticas simples sob pressão de tempo.', NOW(), NOW()),
      ('Procurar uma resposta', 'searching_for_an_answer', 'Esta tarefa irá testar a sua capacidade de identificar rapidamente figuras com formas e cores específicas.', NOW(), NOW()),
      ('Menor que 5', 'greater_than_five', 'Pressione a tecla espaço se o número for menor que 5 e ignore se for maior que 5.', NOW(), NOW())
    """)
  end

  def down do
    alter table(:tasks) do
      remove :description
    end

    execute("DELETE FROM tasks WHERE name IN ('Matemática', 'Procurar uma resposta', 'Menor que 5')")
  end
end
