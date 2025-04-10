defmodule Beam.Repo.Migrations.AddTagsToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :tags, {:array, :string}, default: []
    end

    flush()

    execute("""
    UPDATE tasks SET tags = ARRAY['Atenção Focada', 'Memória de Trabalho', 'Atenção Sustentada', 'Velocidade de Reação']
    WHERE type = 'math_operation'
    """)

    execute("""
    UPDATE tasks SET tags = ARRAY['Atenção Seletiva', 'Atenção Sustentada', 'Velocidade de Reação', 'Atenção Visual']
    WHERE type = 'searching_for_an_answer'
    """)

    execute("""
    UPDATE tasks SET tags = ARRAY['Atenção Focada', 'Velocidade de Reação', 'Inibição de Resposta', 'Atenção Sustentada']
    WHERE type = 'greater_than_five'
    """)

    execute("""
    UPDATE tasks SET tags = ARRAY['Memória de Trabalho', 'Atenção Sustentada', 'Atenção Focada', 'Manipulação Cognitiva']
    WHERE type = 'reverse_sequence'
    """)

    execute("""
    UPDATE tasks SET tags = ARRAY['Memória de Trabalho', 'Atenção Sustentada', 'Velocidade de Reação', 'Atenção Visual']
    WHERE type = 'code_of_symbols'
    """)

    execute("""
    UPDATE tasks SET tags = ARRAY['Atenção Seletiva', 'Inibição de Resposta', 'Velocidade de Reação', 'Flexibilidade Cognitiva']
    WHERE type = 'name_and_color'
    """)

    execute("""
    UPDATE tasks SET tags = ARRAY['Atenção Seletiva', 'Atenção Visual', 'Atenção Sustentada', 'Velocidade de Reação']
    WHERE type = 'follow_the_figure'
    """)
  end
end
