defmodule Beam.Repo.Migrations.UpdateFollowTheFigureDescription do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE tasks
    SET description = 'Uma figura com forma e cor únicas irá aparecer no ecrã juntamente com figuras distratoras. O seu objetivo é clicar na figura correta que vai estar no meio do molho. Ao acertar, ganha tempo; ao errar perde tempo. O exercício termina quando o tempo esgota ou após 20 rondas.

    Níveis:
    - Fácil: Menos figuras distratoras e elas não se movimentam,
    - Médio: Mais figuras distratoras que no fácil e há chance das figuras se moveram,
    - Difícil: Imensas figuras na maioria das rondas e a chance delas se moverem é maior',
        updated_at = NOW()
        WHERE type = 'follow_the_figure'
    """)
  end

  def down do
    execute("""
    UPDATE tasks
    SET description = 'Uma figura com forma e cor únicas irá mover-se pelo ecrã juntamente com figuras distratoras. O seu objetivo é clicar na figura correta enquanto se move. Ao acertar, ganha tempo; ao errar perde tempo. O exercício termina quando o tempo esgota ou após 20 rondas.

    Níveis:
    - Fácil: A cada ronda aumentam 4 distratores,
    - Médio: A cada ronda aumentam 7 distratores,
    - Difícil: A cada ronda aumentam 10 distratores.',
    updated_at = NOW()
    WHERE type = 'follow_the_figure'
    """)
  end
end
