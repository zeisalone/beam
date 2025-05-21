defmodule Beam.Exercices.Configurable do
  @moduledoc """
  Comportamento para tarefas que suportam configurações editáveis por terapeutas.
  """

  @callback default_config() :: map()
  @callback config_spec() :: list({atom(), :integer | :float | :string, keyword()})
  @callback validate_config(map()) :: :ok | {:error, map()}
end
