defmodule HeexFormatter do
  @moduledoc """
  Documentation for `HeexFormatter`.
  """
  @behaviour Mix.Tasks.Format

  alias Phoenix.LiveView.HTMLTokenizer

  @impl Mix.Tasks.Format
  def features(_opts) do
    [sigils: [:H], extensions: [".heex"]]
  end

  @impl Mix.Tasks.Format
  def format(contents, _opts) do
    {text, eex_tokenizer_nodes} = extract_eex_text(contents)
    {html_nodes, :text} = HTMLTokenizer.tokenize(text, "nofile", 0, [], [], :text)

    html_nodes
    |> Enum.reverse()
    |> join_nodes(eex_tokenizer_nodes)
    |> HeexFormatter.Phases.EnsureLineBreaks.run([])
    |> HeexFormatter.Phases.Render.run([])
  end

  def join_nodes(html_nodes, eex_tokenizer_nodes) do
    new_nodes =
      eex_tokenizer_nodes
      |> Enum.reduce([], fn
        {:start_expr, line, column, '=', expr}, acc ->
          [
            {:text, "<%= #{String.trim(to_string(expr))} %>",
             %{column: column + 1, line: line + 1}}
            | acc
          ]

        {:end_expr, line, column, _opts, expr}, acc ->
          [
            {:text, "<% #{String.trim(to_string(expr))} %>",
             %{column: column + 1, line: line + 1}}
            | acc
          ]

        _expr, acc ->
          acc
      end)
      |> Enum.reverse()

    (html_nodes ++ new_nodes)
    |> Enum.reject(&(&1 == {:text, "\n", %{}}))
    |> Enum.sort_by(fn
      {_, _, _, %{line: line, column: column}} ->
        {line, column}

      {_, _, %{column_end: column_end, line_end: line_end}} ->
        {line_end, column_end}

      {_, _, %{column: column, line: line}} ->
        {line, column}
    end)
  end

  defp extract_eex_text(contents) do
    {:ok, nodes} = EEx.Tokenizer.tokenize(contents, 0, 0, %{indentation: 0, trim: false})

    text =
      Enum.reduce(nodes, "", fn
        {:text, _line, _col, text}, acc ->
          acc <> List.to_string(text)

        _node, acc ->
          acc
      end)

    {text, nodes}
  end
end
