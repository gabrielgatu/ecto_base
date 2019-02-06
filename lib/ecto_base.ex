defmodule EctoBase do
  defmacro __using__([]) do
    repo = find_project_repo!()

    quote do
      use Ecto.Schema
      import Ecto.Changeset
      require Ecto.Query

      alias unquote(repo)
      alias __MODULE__
      import EctoBase

      @type t :: %__MODULE__{}
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    repo = find_project_repo!()

    quote do
      unquote(all_by(repo))
      unquote(get_by(repo))
      unquote(create(repo))
      unquote(update_by(repo))
      unquote(delete_by(repo))

      unquote(embed_filters())
    end
  end

  defp all_by(repo) do
    quote do
      @spec all_by(list) :: {:ok, t} | {:error, String.t()}
      def all_by(filters) when is_list(filters) do
        __MODULE__
        |> embed_filters(filters)
        |> unquote(repo).all()
        |> case do
          nil -> {:error, :not_found}
          items -> {:ok, items}
        end
      end
    end
  end

  defp get_by(repo) do
    quote do
      @spec get_by(list) :: {:ok, t} | {:error, String.t()}
      def get_by(filters) when is_list(filters) do
        __MODULE__
        |> unquote(repo).get_by(filters)
        |> case do
          nil -> {:error, :not_found}
          item -> {:ok, item}
        end
      end
    end
  end

  defp create(repo) do
    quote do
      if Module.defines?(__MODULE__, {:create_changeset, 2}) do
        @spec create(map) :: {:ok, t} | {:error, String.t()}
        def create(args) do
          %__MODULE__{}
          |> create_changeset(args)
          |> unquote(repo).insert()
          |> case do
            {:ok, item} -> {:ok, item}
            {:error, changeset} -> {:error, format_errors(changeset)}
          end
        end
      end
    end
  end

  defp update_by(repo) do
    quote do
      if Module.defines?(__MODULE__, {:update_changeset, 2}) do
        @spec update_by(integer, map) :: {:ok, t} | {:error, String.t()}
        def update_by(id, args) when is_integer(id) and is_map(args) do
          __MODULE__
          |> unquote(repo).get!(id)
          |> update_changeset(args)
          |> unquote(repo).update()
          |> case do
            {:ok, item} -> {:ok, item}
            {:error, changeset} -> {:error, format_errors(changeset)}
          end
        end

        @spec update_by(list, map) :: {:ok, t} | {:error, String.t()}
        def update_by(filters, args) when is_list(filters) and is_map(args) do
          with {:ok, item} <- get_by(filters) do
            item
            |> update_changeset(args)
            |> unquote(repo).update()
            |> case do
              {:ok, item} -> {:ok, item}
              {:error, changeset} -> {:error, format_errors(changeset)}
            end
          end
        end
      end
    end
  end

  defp delete_by(repo) do
    quote do
      @spec delete_by(list) :: {:ok, t} | {:error, String.t()}
      def delete_by(filters) when is_list(filters) do
        with {:ok, item} <- get_by(filters) do
          item
          |> unquote(repo).delete()
          |> case do
            {:ok, item} -> {:ok, item}
            {:error, changeset} -> {:error, format_errors(changeset)}
          end
        end
      end
    end
  end

  def embed_filters do
    quote do
      def embed_filters(model, filters) do
        Enum.reduce(filters, model, fn filter, model ->
          embed_filter(model, filter)
        end)
      end

      defp embed_filter(model, filter) do
        Ecto.Query.where(model, ^[filter])
      end
    end
  end

  @spec format_errors(Ecto.Changeset.t()) :: String.t()
  def format_errors(%Ecto.Changeset{errors: errors}) do
    Enum.map(errors, fn {_, {error, _}} -> error end) |> Enum.fetch!(0)
  end

  defp find_project_repo! do
    app = Mix.Project.config()[:app]

    case Application.get_env(app, :ecto_repos) do
      [mod] ->
        mod

      _ ->
        raise("""
        Error: project repo not found. Expected a :ecto_repos key inside your application block in config.exs.

        # Example:
        config #{inspect(app)},
          ecto_repos: [YourApp.Repo]
        """)
    end
  end
end

# defmodule Ecto.Model do
#   use EctoBase

#   schema "diaries" do
#     field(:name, :string)
#   end

#   @spec create_changeset(t, map) :: Changeset.t()
#   defp create_changeset(message, params) do
#     message
#     |> cast(params, [:name])
#     |> validate_required([:name])
#   end
# end
