defmodule Beam.Repo.Migrations.AddNewCognitiveTasks do
  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO tasks (name, type, description, inserted_at, updated_at)
    VALUES (
      'Nome e Cor',
      'name_and_color',
      'Este exercício testa a sua capacidade de resposta e foco. Será exibida uma palavra que representa uma cor, mas a cor da fonte será diferente. Posteriormente, será-lhe colocada uma questão: "Qual era a PALAVRA?" ou "Qual era a COR?". Deve responder dentro do tempo limite.
      \n A diferença entre os níveis de dificuldade é o tempo que a palavra aparece no ecrã.',
      NOW(),
      NOW()
    )
    """)

    execute("""
    INSERT INTO tasks (name, type, description, inserted_at, updated_at)
    VALUES (
      'Segue a Figura',
      'follow_the_figure',
      'Uma figura com forma e cor únicas irá mover-se pelo ecrã juntamente com figuras distratoras. O seu objetivo é clicar na figura correta enquanto se move. Ao acertar, ganha tempo; ao errar perde tempo. O exercício termina quando o tempo esgota ou após 20 rondas.
      \nNíveis:
        - Fácil: A cada ronda aumentam 4 distratores,
        - Médio: A cada ronda aumentam 7 distratores,
        - Difícil: A cada ronda aumentam 10 distratores.',
      NOW(),
      NOW()
    )
    """)
  end

  def down do
    execute("DELETE FROM tasks WHERE type = 'name_and_color'")
    execute("DELETE FROM tasks WHERE type = 'follow_the_figure'")
  end
end
