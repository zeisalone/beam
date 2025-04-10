defmodule Beam.Repo.Migrations.AddImagePathToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :image_path, :string
    end

    flush()

    execute("UPDATE tasks SET image_path = '/images/tasks/Matemática.png' WHERE type = 'math_operation'")
    execute("UPDATE tasks SET image_path = '/images/tasks/Procurar uma Resposta.png' WHERE type = 'searching_for_an_answer'")
    execute("UPDATE tasks SET image_path = '/images/tasks/Menor que 5.png' WHERE type = 'greater_than_five'")
    execute("UPDATE tasks SET image_path = '/images/tasks/Sequencia Inversa.png' WHERE type = 'reverse_sequence'")
    execute("UPDATE tasks SET image_path = '/images/tasks/Código de Simbolos.png' WHERE type = 'code_of_symbols'")
    execute("UPDATE tasks SET image_path = '/images/tasks/Nome e Cor.png' WHERE type = 'name_and_color'")
    execute("UPDATE tasks SET image_path = '/images/tasks/Segue a Figura.png' WHERE type = 'follow_the_figure'")
  end
end
