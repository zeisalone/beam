defmodule Beam.Repo.Migrations.OddOneOut do
  use Ecto.Migration

   def up do
    execute("""
    INSERT INTO tasks (name, type, description, image_path, tags, inserted_at, updated_at)
    VALUES (
      'O diferente',
      'odd_one_out',
      'Neste exercício, vários caracteres (letras ou números) aparecem numa grelha. O objetivo é identificar e clicar no único elemento diferente dos restantes antes do tempo acabar. O tamanho da grelha pode aumentar ou diminuir consoante o desempenho do utilizador. Pode ser jogada com rato em computador e em ambiente táctil.',
      '/images/tasks/O diferente.png',
      ARRAY['Atenção Visual', 'Atenção Focada', 'Discriminação Visual', 'Atenção Seletiva'],
      NOW(), NOW()
    )
    """)
  end

  def down do
    execute("DELETE FROM tasks WHERE type = 'odd_one_out'")
  end
end
