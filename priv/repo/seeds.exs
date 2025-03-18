# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Beam.Repo.insert!(%Beam.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
alias Beam.Repo
alias Beam.Exercices.Task

tasks = [
  %{
    name: "Matemática",
    type: "math_operation",
    description: "Esta tarefa avalia a sua capacidade de resolver operações matemáticas simples sob pressão de tempo."
  },
  %{
    name: "Procurar uma resposta",
    type: "searching_for_an_answer",
    description: "Esta tarefa irá testar a sua capacidade de identificar rapidamente figuras com formas e cores específicas."
  },
  %{
    name: "Menor que 5",
    type: "greater_than_five",
    description: "Pressione a tecla espaço se o número for menor que 5 e ignore se for maior que 5."
  }
]

for task <- tasks do
  existing_task = Repo.get_by(Task, name: task.name)

  if existing_task do
    existing_task
    |> Task.changeset(%{description: task.description})
    |> Repo.update!()
  else
    Repo.insert!(%Task{
      name: task.name,
      type: task.type,
      description: task.description
    })
  end
end
