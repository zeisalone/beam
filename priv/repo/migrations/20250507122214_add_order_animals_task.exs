defmodule Beam.Repo.Migrations.AddOrderAnimalsTask do
  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO tasks (name, type, description, image_path, tags, inserted_at, updated_at)
    VALUES (
      'Ordenar os Animais',
      'order_animals',
      'Neste exercício, vários animais irão aparecer no ecrã durante várias rondas, um de cada vez. No final, o utilizador deverá ordenar os animais pela ordem correta em que foram apresentados, arrastando-os para os espaços correspondentes.',
      '/images/tasks/Ordenar os Animais.png',
      ARRAY['Atenção Focada', 'Atenção Sustentada', 'Atenção Visual', 'Memória de Trabalho'],
      NOW(), NOW()
    )
    """)
  end

  def down do
    execute("DELETE FROM tasks WHERE type = 'order_animals'")
  end
end
