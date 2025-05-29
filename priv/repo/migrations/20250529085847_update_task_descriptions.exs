defmodule Beam.Repo.Migrations.UpdateTaskDescriptions do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE tasks SET description = 'Esta tarefa testa a sua capacidade de calcular rapidamente. Irá aparecer no ecrã uma operação matématica, cuja complexidade depende do nível de dificuldade que o utilizador terá alguns segundos para resolver, selecionando a opção correta. Pode ser jogada com rato e em ambiente táctil.' WHERE type = 'math_operation';
    """)

    execute("""
    UPDATE tasks SET description = 'Nesta tarefa, o seu desafio é encontrar rapidamente uma figura com características específicas (forma e cor) entre distratores. A maneira de o fazer é usando as setas dependendo do sitio onde a figura alvo se encontra. Só pode ser jogada em computador com rato.' WHERE type = 'searching_for_an_answer';
    """)

    execute("""
    UPDATE tasks SET description = 'Sempre que surgir um número no ecrã, carregue na barra de espaço apenas se for menor que 5. Só pode ser jogada em computador com rato e teclado.' WHERE type = 'less_than_five';
    """)

    execute("""
    UPDATE tasks SET description = 'Memorize e depois escreva a sequência de números ao contrário. Pode ser jogada com rato e em ambiente táctil (mas com rato é mais recomendado, ambiente táctil fica mais lento).' WHERE type = 'reverse_sequence';
    """)

    execute("""
    UPDATE tasks SET description = 'Associe corretamente os símbolos coloridos aos números correspondentes. Memorize o código apresentado (símbolo associado a um número) e preencha a grelha digitando o número correto de cada símbolo. O utilizador vê o código e carrega manualmente em começar. Atenção que há tempo limite para responder. Pode ser jogada com rato e em ambiente táctil (mas com rato é mais recomendado, ambiente táctil fica mais lento).' WHERE type = 'code_of_symbols';
    """)

    execute("""
    UPDATE tasks SET description = 'Será exibida uma palavra que representa uma cor, mas a cor que de que está pintada a palavra será diferente. Posteriormente, será-lhe colocada uma questão: "Qual era a PALAVRA?" ou "Qual era a COR?". Deve responder dentro do tempo limite. Pode ser jogada com rato e em ambiente táctil.' WHERE type = 'name_and_color';
    """)

    execute("""
    UPDATE tasks SET description = 'Uma figura com forma e cor únicas irá aparecer no ecrã juntamente com figuras distratoras. O seu objetivo é clicar na figura correta que vai estar no meio da confusão. Ao acertar, ganha tempo; ao errar perde tempo. O exercício termina quando o tempo esgota ou quando se responde ao número de respostas pretendidas. Pode ser jogada com rato e em ambiente táctil (para ambiente táctil recomenda-se o uso de uma caneta própria, ou algo parecido).' WHERE type = 'follow_the_figure';
    """)

    execute("""
    UPDATE tasks SET description = 'Este exercício é inspirado no clássico jogo Simon. Serão apresentados botões com cores em sequência crescente. O seu objetivo é repetir corretamente a sequência. Se errar, volta ao nível mais baixo, onde a sequência será diferente. Pode ser jogada com rato e em ambiente táctil.' WHERE type = 'simon';
    """)

    execute("""
    UPDATE tasks SET description = 'Neste exercício, uma vogal com uma cor específica será apresentada como alvo no início do jogo. Em seguida, várias vogais coloridas surgem no ecrã, cada uma numa posição diferente. O seu objetivo é clicar rapidamente na vogal que corresponde exatamente ao alvo apresentado, tanto na letra como na cor. A tarefa avança automaticamente após um curto período de tempo, com ou sem resposta. Pode ser jogada com rato e em ambiente táctil.' WHERE type = 'searching_for_a_vowel';
    """)

    execute("""
    UPDATE tasks SET description = 'Neste exercício, vários animais irão aparecer no ecrã durante várias rondas, um de cada vez. No final, o utilizador deverá ordenar os animais pela ordem correta em que foram apresentados, arrastando-os para os espaços correspondentes. Só pode ser jogada com rato.' WHERE type = 'order_animals';
    """)
  end

  def down do
    raise "Irreversível: esta migração substitui descrições anteriores."
  end
end
