defmodule Beam.Repo.Migrations.SeedTasks do
  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO tasks (name, type, description, image_path, tags, inserted_at, updated_at)
    VALUES
      (
        'Matemática',
        'math_operation',
        'Esta tarefa testa a sua capacidade de calcular rapidamente. Irá aparecer no ecrã uma operação matématica, cuja complexidade depende do nível de dificuldade que o utilizador depois terá alguns segundos para resolver, selecionando a opção correta.',
        '/images/tasks/Matemática.png',
        ARRAY['Atenção Focada', 'Memória de Trabalho', 'Atenção Sustentada', 'Velocidade de Reação'],
        NOW(), NOW()
      ),
      (
        'Procurar uma resposta',
        'searching_for_an_answer',
        'Nesta tarefa, o seu desafio é encontrar rapidamente uma figura com características específicas (forma e cor) entre distratores.\n A maneira de o fazer é usando as setas dependendo do sitio onde a figura alvo se encontra.',
        '/images/tasks/Procurar uma Resposta.png',
        ARRAY['Atenção Seletiva', 'Atenção Sustentada', 'Velocidade de Reação', 'Atenção Visual'],
        NOW(), NOW()
      ),
      (
        'Menor que 5',
        'less_than_five',
        'Sempre que surgir um número no ecrã, carregue na barra de espaço apenas se for menor que 5. Este exercício exige foco, rapidez e capacidade de inibir respostas automáticas.',
        '/images/tasks/Menor que 5.png',
        ARRAY['Atenção Focada', 'Velocidade de Reação', 'Inibição de Resposta', 'Atenção Sustentada'],
        NOW(), NOW()
      ),
      (
        'Sequência Inversa',
        'reverse_sequence',
        'Memorize e depois escreva a sequência de números ao contrário. Atenção que um número uma vez escrito não pode ser apagado.\nCom o aumento do nível de dificuldade, aumenta o número de algarismos.',
        '/images/tasks/Sequencia Inversa.png',
        ARRAY['Memória de Trabalho', 'Atenção Sustentada', 'Atenção Focada', 'Manipulação Cognitiva'],
        NOW(), NOW()
      ),
      (
        'Código de Símbolos',
        'code_of_symbols',
        'Associe corretamente os símbolos coloridos aos números correspondentes. Memorize o código apresentado (símbolo com número) e preencha a grelha digitando o número correto de cada símbolo.\n\nNíveis:\n- Fácil: 4 símbolos únicos, grelha 4x4\n- Médio: 6 símbolos únicos, grelha 5x5\n- Difícil: 8 símbolos únicos, grelha 6x6\n\nO utilizador vê o código e carrega manualmente em começar. Depois disso, tem 45 segundos para responder.',
        '/images/tasks/Código de Simbolos.png',
        ARRAY['Memória de Trabalho', 'Atenção Sustentada', 'Velocidade de Reação', 'Atenção Visual'],
        NOW(), NOW()
      ),
      (
        'Stroop',
        'name_and_color',
        'Este exercício testa a sua capacidade de resposta e foco. Será exibida uma palavra que representa uma cor, mas a cor da fonte será diferente. Posteriormente, será-lhe colocada uma questão: "Qual era a PALAVRA?" ou "Qual era a COR?". Deve responder dentro do tempo limite.\nA diferença entre os níveis de dificuldade é o tempo que a palavra aparece no ecrã.',
        '/images/tasks/Nome e Cor.png',
        ARRAY['Atenção Seletiva', 'Inibição de Resposta', 'Velocidade de Reação', 'Flexibilidade Cognitiva'],
        NOW(), NOW()
      ),
      (
        'Segue a Figura',
        'follow_the_figure',
        'Uma figura com forma e cor únicas irá aparecer no ecrã juntamente com figuras distratoras. O seu objetivo é clicar na figura correta que vai estar no meio do molho. Ao acertar, ganha tempo; ao errar perde tempo. O exercício termina quando o tempo esgota ou após 20 rondas.\n\nNíveis:\n- Fácil: Menos figuras distratoras e elas não se movimentam,\n- Médio: Mais figuras distratoras que no fácil e há chance das figuras se moverem,\n- Difícil: Imensas figuras na maioria das rondas e a chance delas se moverem é maior.',
        '/images/tasks/Segue a Figura.png',
        ARRAY['Atenção Seletiva', 'Atenção Visual', 'Atenção Sustentada', 'Velocidade de Reação'],
        NOW(), NOW()
      )
    """)
  end

  def down do
    execute("DELETE FROM tasks")
  end
end
