defmodule Beam.Repo.Migrations.AddSimonTask do
  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO tasks (name, type, description, image_path, tags, inserted_at, updated_at)
    VALUES (
      'Simon',
      'simon',
      'Este exercício é inspirado no clássico jogo Simon.\n\nSerão apresentados sons e cores em sequência crescente. O seu objetivo é repetir corretamente a sequência.\n\nA dificuldade define o número de botões coloridos disponíveis:\n- Fácil: 4\n- Médio: 6\n- Difícil: 9\n\nA sequência pode chegar até 7 repetições corretas.\nTem 2 minutos para completar o exercício. Se errar, a sequência recomeça e é registado um erro.',
      '/images/tasks/Simon.png',
      ARRAY['Memória de Trabalho', 'Atenção Sustentada', 'Velocidade de Reação', 'Atenção Visual'],
      NOW(), NOW()
    )
    """)
  end

  def down do
    execute("DELETE FROM tasks WHERE type = 'simon'")
  end
end
