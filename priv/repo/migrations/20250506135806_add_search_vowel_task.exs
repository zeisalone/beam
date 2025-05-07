defmodule Beam.Repo.Migrations.AddSearchVowelTask do
  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO tasks (name, type, description, image_path, tags, inserted_at, updated_at)
    VALUES (
      'Procurar a Vogal',
      'searching_for_a_vowel',
      'Neste exercício, uma vogal com uma cor específica será apresentada como alvo no início de cada ronda. Em seguida, várias vogais coloridas surgem no ecrã, cada uma numa posição diferente. O seu objetivo é clicar rapidamente na vogal que corresponde exatamente ao alvo apresentado, tanto na letra como na cor. A tarefa avança automaticamente após um curto período de tempo, com ou sem resposta.',
      '/images/tasks/Procurar a Vogal.png',
      ARRAY['Atenção Seletiva', 'Atenção Sustentada', 'Velocidade de Reação', 'Atenção Visual'],
      NOW(), NOW()
    )
    """)
  end

  def down do
    execute("DELETE FROM tasks WHERE type = 'searching_for_a_vowel'")
  end
end
