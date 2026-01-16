defmodule Mix.Tasks.BuildDictionary do
  @moduledoc """
  Builds a comprehensive en-definitions.json from WordNet and Wordset data.

  Usage:
      mix build_dictionary

  This parses WordNet 3.1 and Wordset dictionary data, matches definitions against
  the existing en-words.json word list, and uses morphological analysis to maximize coverage.
  """
  use Mix.Task

  @shortdoc "Build comprehensive dictionary definitions from WordNet + Wordset"

  @wordnet_dir "priv/wordnet/dict"
  @wordset_dir "priv/wiktionary"
  @words_file "priv/static/dictionary/en-words.json"
  @output_file "priv/static/dictionary/en-definitions.json"

  @pos_config %{
    "noun" => %{index: "index.noun", data: "data.noun", exc: "noun.exc"},
    "verb" => %{index: "index.verb", data: "data.verb", exc: "verb.exc"},
    "adj" => %{index: "index.adj", data: "data.adj", exc: "adj.exc"},
    "adv" => %{index: "index.adv", data: "data.adv", exc: "adv.exc"}
  }

  @pos_labels %{
    "noun" => "noun",
    "verb" => "verb",
    "adj" => "adjective",
    "adv" => "adverb"
  }

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Loading target word list...")
    target_words = load_target_words()
    target_set = MapSet.new(target_words)
    Mix.shell().info("Loaded #{length(target_words)} target words")

    Mix.shell().info("\n[1/4] Parsing WordNet data files...")
    {wordnet_defs, base_to_inflected} = build_wordnet_definitions(target_set)
    Mix.shell().info("  WordNet direct matches: #{map_size(wordnet_defs)}")

    Mix.shell().info("\n[2/4] Parsing Wordset dictionary files...")
    wordset_defs = build_wordset_definitions(target_set)
    Mix.shell().info("  Wordset matches: #{map_size(wordset_defs)}")

    Mix.shell().info("\n[3/4] Merging definitions...")
    merged = merge_definitions(wordnet_defs, wordset_defs)
    Mix.shell().info("  Merged unique words: #{map_size(merged)}")

    Mix.shell().info("\n[4/5] Propagating to inflected forms...")
    wordset_inflections = build_wordset_inflections(merged, target_set)

    all_inflections =
      Map.merge(base_to_inflected, wordset_inflections, fn _k, v1, v2 -> Enum.uniq(v1 ++ v2) end)

    all_defs = propagate_inflected_definitions(merged, all_inflections, target_set)

    Mix.shell().info("\n[5/5] Writing output file...")
    write_output(all_defs)

    matched = map_size(all_defs)
    total = length(target_words)
    percentage = Float.round(matched / total * 100, 1)

    Mix.shell().info("""

    ✓ Dictionary built successfully!
      - Words with definitions: #{matched}
      - Total words in list: #{total}
      - Coverage: #{percentage}%
      - Output: #{@output_file}
    """)
  end

  defp load_target_words do
    @words_file
    |> File.read!()
    |> Jason.decode!()
  end

  defp build_wordnet_definitions(target_set) do
    results =
      @pos_config
      |> Task.async_stream(
        fn {pos, config} -> parse_wordnet_pos(pos, config, target_set) end,
        timeout: :infinity,
        ordered: false
      )
      |> Enum.map(fn {:ok, result} -> result end)

    direct_defs =
      results
      |> Enum.map(& &1.definitions)
      |> Enum.reduce(%{}, &merge_definitions(&2, &1))

    base_to_inflected =
      results
      |> Enum.flat_map(& &1.inflections)
      |> Enum.group_by(fn {_inflected, base} -> base end, fn {inflected, _base} -> inflected end)

    {direct_defs, base_to_inflected}
  end

  defp build_wordset_definitions(target_set) do
    letters = ~w(a b c d e f g h i j k l m n o p q r s t u v w x y z)

    letters
    |> Task.async_stream(
      fn letter -> parse_wordset_file(letter, target_set) end,
      timeout: :infinity,
      ordered: false
    )
    |> Enum.reduce(%{}, fn {:ok, defs}, acc -> merge_definitions(acc, defs) end)
  end

  defp parse_wordset_file(letter, target_set) do
    path = Path.join(@wordset_dir, "#{letter}.json")

    if File.exists?(path) do
      path
      |> File.read!()
      |> Jason.decode!()
      |> Enum.reduce(%{}, fn {word, entry}, acc ->
        normalized = String.downcase(word)

        if MapSet.member?(target_set, normalized) do
          defs = extract_wordset_meanings(entry)
          if defs == [], do: acc, else: Map.put(acc, normalized, defs)
        else
          acc
        end
      end)
    else
      %{}
    end
  end

  defp extract_wordset_meanings(%{"meanings" => meanings}) when is_list(meanings) do
    meanings
    |> Enum.take(3)
    |> Enum.map(fn meaning ->
      %{
        "pos" => normalize_pos(meaning["speech_part"]),
        "def" => meaning["def"]
      }
    end)
    |> Enum.reject(fn m -> is_nil(m["def"]) or m["def"] == "" end)
  end

  defp extract_wordset_meanings(_), do: []

  defp normalize_pos("noun"), do: "noun"
  defp normalize_pos("verb"), do: "verb"
  defp normalize_pos("adjective"), do: "adjective"
  defp normalize_pos("adverb"), do: "adverb"
  defp normalize_pos("preposition"), do: "preposition"
  defp normalize_pos("conjunction"), do: "conjunction"
  defp normalize_pos("interjection"), do: "interjection"
  defp normalize_pos("pronoun"), do: "pronoun"
  defp normalize_pos("determiner"), do: "determiner"
  defp normalize_pos("article"), do: "article"
  defp normalize_pos(other) when is_binary(other), do: other
  defp normalize_pos(_), do: nil

  defp parse_wordnet_pos(pos, config, target_set) do
    Mix.shell().info("  Parsing WordNet #{pos}...")

    synset_map = build_synset_map(config.data)
    {word_offsets, all_words} = parse_index_file(config.index, target_set)
    exceptions = parse_exception_file(config.exc, target_set)

    definitions =
      word_offsets
      |> Enum.reduce(%{}, fn {word, offsets}, acc ->
        defs = build_word_defs(offsets, synset_map, pos)
        if defs == [], do: acc, else: Map.put(acc, word, defs)
      end)

    inflections = build_inflection_map(exceptions, all_words, target_set, pos)

    %{definitions: definitions, inflections: inflections}
  end

  defp build_word_defs(offsets, synset_map, pos) do
    offsets
    |> Enum.map(&Map.get(synset_map, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.take(3)
    |> Enum.map(fn def -> %{"pos" => @pos_labels[pos], "def" => def} end)
  end

  defp build_inflection_map(exceptions, wordnet_words, target_set, pos) do
    from_exceptions =
      exceptions
      |> Enum.filter(fn {inflected, _base} -> MapSet.member?(target_set, inflected) end)

    from_stemming =
      target_set
      |> Enum.flat_map(fn word ->
        stem_word(word, pos)
        |> Enum.filter(&MapSet.member?(wordnet_words, &1))
        |> Enum.map(fn base -> {word, base} end)
      end)

    from_exceptions ++ from_stemming
  end

  defp stem_word(word, "verb") do
    cond do
      String.ends_with?(word, "ies") ->
        [String.slice(word, 0..-4//1) <> "y"]

      String.ends_with?(word, "es") ->
        [String.slice(word, 0..-3//1), String.slice(word, 0..-2//1)]

      String.ends_with?(word, "ed") ->
        [
          String.slice(word, 0..-3//1),
          String.slice(word, 0..-2//1),
          String.slice(word, 0..-3//1) <> "e"
        ]

      String.ends_with?(word, "ing") ->
        [String.slice(word, 0..-4//1), String.slice(word, 0..-4//1) <> "e"]

      String.ends_with?(word, "s") ->
        [String.slice(word, 0..-2//1)]

      true ->
        []
    end
    |> Enum.reject(&(&1 == "" or &1 == word))
  end

  defp stem_word(word, "noun") do
    cond do
      String.ends_with?(word, "ies") ->
        [String.slice(word, 0..-4//1) <> "y"]

      String.ends_with?(word, "es") ->
        [String.slice(word, 0..-3//1), String.slice(word, 0..-2//1)]

      String.ends_with?(word, "s") ->
        [String.slice(word, 0..-2//1)]

      true ->
        []
    end
    |> Enum.reject(&(&1 == "" or &1 == word))
  end

  defp stem_word(word, "adj") do
    cond do
      String.ends_with?(word, "er") ->
        [String.slice(word, 0..-3//1), String.slice(word, 0..-3//1) <> "e"]

      String.ends_with?(word, "est") ->
        [String.slice(word, 0..-4//1), String.slice(word, 0..-4//1) <> "e"]

      String.ends_with?(word, "ier") ->
        [String.slice(word, 0..-4//1) <> "y"]

      String.ends_with?(word, "iest") ->
        [String.slice(word, 0..-5//1) <> "y"]

      true ->
        []
    end
    |> Enum.reject(&(&1 == "" or &1 == word))
  end

  defp stem_word(_word, _pos), do: []

  defp build_wordset_inflections(merged_defs, target_set) do
    defined_words = Map.keys(merged_defs) |> MapSet.new()

    target_set
    |> Task.async_stream(
      fn word ->
        stems =
          stem_all(word)
          |> Enum.filter(&MapSet.member?(defined_words, &1))
          |> Enum.map(fn base -> {base, word} end)

        stems
      end,
      timeout: :infinity,
      ordered: false
    )
    |> Enum.flat_map(fn {:ok, pairs} -> pairs end)
    |> Enum.group_by(fn {base, _} -> base end, fn {_, inflected} -> inflected end)
  end

  defp stem_all(word) do
    stems = []

    stems =
      stems ++
        cond do
          String.ends_with?(word, "ies") ->
            [String.slice(word, 0..-4//1) <> "y"]

          String.ends_with?(word, "es") ->
            [String.slice(word, 0..-3//1), String.slice(word, 0..-2//1)]

          String.ends_with?(word, "s") and not String.ends_with?(word, "ss") ->
            [String.slice(word, 0..-2//1)]

          true ->
            []
        end

    stems =
      stems ++
        cond do
          String.ends_with?(word, "ed") ->
            [
              String.slice(word, 0..-3//1),
              String.slice(word, 0..-2//1),
              String.slice(word, 0..-3//1) <> "e"
            ]

          String.ends_with?(word, "ing") ->
            [String.slice(word, 0..-4//1), String.slice(word, 0..-4//1) <> "e"]

          true ->
            []
        end

    stems =
      stems ++
        cond do
          String.ends_with?(word, "ier") ->
            [String.slice(word, 0..-4//1) <> "y"]

          String.ends_with?(word, "iest") ->
            [String.slice(word, 0..-5//1) <> "y"]

          String.ends_with?(word, "er") ->
            [String.slice(word, 0..-3//1), String.slice(word, 0..-3//1) <> "e"]

          String.ends_with?(word, "est") ->
            [String.slice(word, 0..-4//1), String.slice(word, 0..-4//1) <> "e"]

          true ->
            []
        end

    stems =
      stems ++
        cond do
          String.ends_with?(word, "ly") ->
            [String.slice(word, 0..-3//1), String.slice(word, 0..-3//1) <> "le"]

          String.ends_with?(word, "ily") ->
            [String.slice(word, 0..-4//1) <> "y"]

          true ->
            []
        end

    stems =
      stems ++
        cond do
          String.ends_with?(word, "ness") ->
            [String.slice(word, 0..-5//1)]

          String.ends_with?(word, "iness") ->
            [String.slice(word, 0..-6//1) <> "y"]

          String.ends_with?(word, "ment") ->
            [String.slice(word, 0..-5//1), String.slice(word, 0..-5//1) <> "e"]

          String.ends_with?(word, "tion") ->
            [
              String.slice(word, 0..-5//1),
              String.slice(word, 0..-5//1) <> "e",
              String.slice(word, 0..-4//1) <> "e"
            ]

          String.ends_with?(word, "able") ->
            [String.slice(word, 0..-5//1), String.slice(word, 0..-5//1) <> "e"]

          String.ends_with?(word, "ible") ->
            [String.slice(word, 0..-5//1), String.slice(word, 0..-5//1) <> "e"]

          true ->
            []
        end

    stems
    |> Enum.reject(&(&1 == "" or &1 == word or String.length(&1) < 2))
    |> Enum.uniq()
  end

  defp propagate_inflected_definitions(direct_defs, base_to_inflected, target_set) do
    base_to_inflected
    |> Enum.reduce(direct_defs, fn {base, inflected_forms}, acc ->
      case Map.get(direct_defs, base) do
        nil ->
          acc

        base_defs ->
          inflected_forms
          |> Enum.filter(&MapSet.member?(target_set, &1))
          |> Enum.reduce(acc, fn inflected, inner_acc ->
            Map.update(inner_acc, inflected, base_defs, fn existing ->
              (existing ++ base_defs) |> Enum.uniq_by(& &1["def"]) |> Enum.take(5)
            end)
          end)
      end
    end)
  end

  defp build_synset_map(data_file) do
    Path.join(@wordnet_dir, data_file)
    |> File.stream!()
    |> Stream.reject(&String.starts_with?(&1, "  "))
    |> Stream.map(&parse_data_line/1)
    |> Stream.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp parse_data_line(line) do
    case String.split(line, " | ", parts: 2) do
      [header, gloss] ->
        offset = header |> String.split(" ", parts: 2) |> hd() |> String.trim()
        definition = gloss |> String.split(";") |> hd() |> String.trim()
        {offset, definition}

      _ ->
        nil
    end
  end

  defp parse_index_file(index_file, target_set) do
    {matches, all_words} =
      Path.join(@wordnet_dir, index_file)
      |> File.stream!()
      |> Stream.reject(&String.starts_with?(&1, "  "))
      |> Enum.reduce({%{}, MapSet.new()}, fn line, {matches_acc, words_acc} ->
        case parse_index_line(line, target_set) do
          {word, offsets, raw_word} ->
            {Map.put(matches_acc, word, offsets), MapSet.put(words_acc, raw_word)}

          {:skip, raw_word} ->
            {matches_acc, MapSet.put(words_acc, raw_word)}

          nil ->
            {matches_acc, words_acc}
        end
      end)

    {matches, all_words}
  end

  defp parse_index_line(line, target_set) do
    parts = String.split(line)

    case parts do
      [word | rest] when length(rest) >= 4 ->
        normalized = word |> String.replace("_", " ") |> String.downcase()
        offsets = extract_offsets(rest)

        cond do
          MapSet.member?(target_set, normalized) -> {normalized, offsets, word}
          MapSet.member?(target_set, word) -> {word, offsets, word}
          true -> {:skip, word}
        end

      _ ->
        nil
    end
  end

  defp extract_offsets(parts) do
    parts
    |> Enum.reverse()
    |> Enum.take_while(&String.match?(&1, ~r/^\d{8}$/))
    |> Enum.reverse()
  end

  defp parse_exception_file(exc_file, target_set) do
    path = Path.join(@wordnet_dir, exc_file)

    if File.exists?(path) do
      path
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Stream.map(&String.split(&1, " "))
      |> Stream.filter(fn parts -> length(parts) >= 2 end)
      |> Stream.map(fn [inflected | bases] -> {inflected, hd(bases)} end)
      |> Stream.filter(fn {inflected, _} -> MapSet.member?(target_set, inflected) end)
      |> Enum.to_list()
    else
      []
    end
  end

  defp merge_definitions(acc, new_defs) do
    Map.merge(acc, new_defs, fn _word, existing, incoming ->
      (existing ++ incoming) |> Enum.uniq_by(& &1["def"]) |> Enum.take(5)
    end)
  end

  defp write_output(definitions) do
    json =
      definitions
      |> Enum.sort_by(fn {word, _} -> word end)
      |> Enum.map(fn {word, defs} ->
        escaped_word = String.replace(word, "\"", "\\\"")
        formatted_defs = Jason.encode!(defs)
        ~s("#{escaped_word}": #{formatted_defs})
      end)
      |> Enum.join(",\n  ")

    content = "{\n  #{json}\n}\n"
    File.write!(@output_file, content)
  end
end
