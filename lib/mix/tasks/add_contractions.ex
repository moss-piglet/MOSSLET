defmodule Mix.Tasks.AddContractions do
  @moduledoc """
  Adds common English contractions to en-words.json word list.

  Usage:
      mix add_contractions
  """
  use Mix.Task

  @shortdoc "Add contractions to word list"

  @words_file "priv/static/dictionary/en-words.json"

  @contractions [
    "aren't",
    "can't",
    "couldn't",
    "didn't",
    "doesn't",
    "don't",
    "hadn't",
    "hasn't",
    "haven't",
    "he'd",
    "he'll",
    "he's",
    "here's",
    "i'd",
    "i'll",
    "i'm",
    "i've",
    "isn't",
    "it'd",
    "it'll",
    "it's",
    "let's",
    "mightn't",
    "mustn't",
    "needn't",
    "shan't",
    "she'd",
    "she'll",
    "she's",
    "shouldn't",
    "that'd",
    "that'll",
    "that's",
    "there'd",
    "there'll",
    "there's",
    "they'd",
    "they'll",
    "they're",
    "they've",
    "wasn't",
    "we'd",
    "we'll",
    "we're",
    "we've",
    "weren't",
    "what'd",
    "what'll",
    "what're",
    "what's",
    "what've",
    "when's",
    "where'd",
    "where's",
    "where've",
    "who'd",
    "who'll",
    "who're",
    "who's",
    "who've",
    "why'd",
    "why'll",
    "why's",
    "won't",
    "wouldn't",
    "y'all",
    "you'd",
    "you'll",
    "you're",
    "you've",
    "ain't",
    "could've",
    "would've",
    "should've",
    "might've",
    "must've",
    "how'd",
    "how'll",
    "how's",
    "ma'am",
    "o'clock",
    "ne'er",
    "e'er",
    "o'er",
    "'twas",
    "'tis",
    "y'know",
    "c'mon",
    "gonna",
    "gotta",
    "wanna",
    "kinda",
    "sorta",
    "dunno",
    "gimme",
    "lemme"
  ]

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Loading word list...")
    words = load_words()
    original_count = length(words)
    Mix.shell().info("Current word count: #{original_count}")

    word_set = MapSet.new(words)

    new_words =
      @contractions
      |> Enum.reject(&MapSet.member?(word_set, &1))

    Mix.shell().info("Adding #{length(new_words)} new contractions...")

    if new_words != [] do
      all_words =
        (words ++ new_words)
        |> Enum.sort()
        |> Enum.uniq()

      write_words(all_words)

      Mix.shell().info("""

      ✓ Contractions added successfully!
        - Original words: #{original_count}
        - Added: #{length(new_words)}
        - New total: #{length(all_words)}
        - Output: #{@words_file}

      New contractions added:
      #{Enum.join(new_words, ", ")}
      """)
    else
      Mix.shell().info("All contractions already present in word list.")
    end
  end

  defp load_words do
    @words_file
    |> File.read!()
    |> Jason.decode!()
  end

  defp write_words(words) do
    json = Jason.encode!(words, pretty: false)
    File.write!(@words_file, json)
  end
end
