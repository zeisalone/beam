defmodule Beam.Repo.Migrations.AddReverseSequenceTask do
  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO tasks (name, type, description, inserted_at, updated_at)
    VALUES
      ('Sequência Inversa', 'reverse_sequence', 'Memorize e depois escreva a sequência de números ao contrário. Atenção que um número uma vez escrito não pode ser apagado \n Com o aumento do nível de difículdade aumenta o número de algarísmos.', NOW(), NOW())
    """)
  end

  def down do
    execute("DELETE FROM tasks WHERE type = 'reverse_sequence'")
  end
end
