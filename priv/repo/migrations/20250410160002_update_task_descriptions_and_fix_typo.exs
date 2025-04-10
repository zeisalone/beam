defmodule Beam.Repo.Migrations.UpdateTaskDescriptionsAndFixTypo do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE tasks
    SET type = 'less_than_five', updated_at = NOW()
    WHERE type = 'greater_than_five'
    """)

    execute("""
    UPDATE tasks
    SET description = 'Esta tarefa testa a sua capacidade de calcular rapidamente. Irá aparecer no ecrã uma operação matématica, cuja complexidade depende do nível de dificuldade que o utilizador depois terá alguns segundos para resolver, selecionando a opção correta.'
    WHERE type = 'math_operation'
    """)

    execute("""
    UPDATE tasks
    SET description = 'Nesta tarefa, o seu desafio é encontrar rapidamente uma figura com características específicas (forma e cor) entre distratores.\n A maneira de o fazer é usando as setas dependendo do sitio onde a figura alvo se encontra.'
    WHERE type = 'searching_for_an_answer'
    """)

    execute("""
    UPDATE tasks
    SET description = 'Sempre que surgir um número no ecrã, carregue na barra de espaço apenas se for menor que 5. Este exercício exige foco, rapidez e capacidade de inibir respostas automáticas.'
    WHERE type = 'less_than_five'
    """)
  end
end
