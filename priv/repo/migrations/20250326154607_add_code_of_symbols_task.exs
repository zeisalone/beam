defmodule Beam.Repo.Migrations.AddCodeOfSymbolsTask do
  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO tasks (name, type, description, inserted_at, updated_at)
    VALUES (
      'Código de Símbolos',
      'code_of_symbols',
      'Associe corretamente os símbolos coloridos aos números correspondentes. Memorize o código apresentado (símbolo com número) e preencha a grelha digitando o número correto de cada símbolo.
      \nNíveis:
        - Fácil: 4 símbolos únicos, grelha 4x4
        - Médio: 6 símbolos únicos, grelha 5x5
        - Difícil: 8 símbolos únicos, grelha 6x6
      \nO utilizador vê o código e carrega manualmente em começar. Depois disso, tem 45 segundos para responder.',
      NOW(),
      NOW()
    )
    """)
  end

  def down do
    execute("DELETE FROM tasks WHERE type = 'code_of_symbols'")
  end
end
