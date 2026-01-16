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
    "noun" => %{index: "index.noun", data: "data.noun"},
    "verb" => %{index: "index.verb", data: "data.verb"},
    "adj" => %{index: "index.adj", data: "data.adj"},
    "adv" => %{index: "index.adv", data: "data.adv"}
  }

  @pos_labels %{
    "noun" => "noun",
    "verb" => "verb",
    "adj" => "adjective",
    "adv" => "adverb"
  }

  @function_words %{
    "a" => [
      %{
        "pos" => "article",
        "def" => "used before singular nouns to refer to one unspecified thing or person"
      }
    ],
    "an" => [
      %{"pos" => "article", "def" => "form of 'a' used before words beginning with a vowel sound"}
    ],
    "the" => [
      %{
        "pos" => "article",
        "def" =>
          "used to refer to a specific person, thing, or group already mentioned or understood"
      }
    ],
    "this" => [
      %{
        "pos" => "determiner",
        "def" => "used to identify a specific person or thing close at hand or being indicated"
      }
    ],
    "that" => [
      %{
        "pos" => "determiner",
        "def" => "used to identify a specific person or thing observed or heard by the speaker"
      }
    ],
    "these" => [
      %{
        "pos" => "determiner",
        "def" => "plural of 'this'; used to identify specific things close at hand"
      }
    ],
    "those" => [
      %{
        "pos" => "determiner",
        "def" => "plural of 'that'; used to identify specific things at a distance"
      }
    ],
    "is" => [%{"pos" => "verb", "def" => "third person singular present of 'be'"}],
    "am" => [%{"pos" => "verb", "def" => "first person singular present of 'be'"}],
    "are" => [%{"pos" => "verb", "def" => "second person singular and plural present of 'be'"}],
    "was" => [%{"pos" => "verb", "def" => "first and third person singular past of 'be'"}],
    "were" => [%{"pos" => "verb", "def" => "second person singular and plural past of 'be'"}],
    "been" => [%{"pos" => "verb", "def" => "past participle of 'be'"}],
    "being" => [%{"pos" => "verb", "def" => "present participle of 'be'"}],
    "be" => [
      %{
        "pos" => "verb",
        "def" => "exist or live; used to link the subject with information about it"
      }
    ],
    "have" => [%{"pos" => "verb", "def" => "possess, own, or hold; used to form perfect tenses"}],
    "has" => [%{"pos" => "verb", "def" => "third person singular present of 'have'"}],
    "had" => [%{"pos" => "verb", "def" => "past tense and past participle of 'have'"}],
    "having" => [%{"pos" => "verb", "def" => "present participle of 'have'"}],
    "do" => [
      %{"pos" => "verb", "def" => "perform an action; used to form questions and negatives"}
    ],
    "does" => [%{"pos" => "verb", "def" => "third person singular present of 'do'"}],
    "did" => [%{"pos" => "verb", "def" => "past tense of 'do'"}],
    "done" => [%{"pos" => "verb", "def" => "past participle of 'do'"}],
    "doing" => [%{"pos" => "verb", "def" => "present participle of 'do'"}],
    "will" => [
      %{
        "pos" => "verb",
        "def" => "expressing the future tense; expressing intention or willingness"
      }
    ],
    "would" => [%{"pos" => "verb", "def" => "past tense of 'will'; expressing conditional mood"}],
    "shall" => [
      %{
        "pos" => "verb",
        "def" => "expressing the future tense; expressing determination or obligation"
      }
    ],
    "should" => [%{"pos" => "verb", "def" => "used to indicate obligation, duty, or correctness"}],
    "can" => [%{"pos" => "verb", "def" => "be able to; have permission to"}],
    "could" => [%{"pos" => "verb", "def" => "past tense of 'can'; used to indicate possibility"}],
    "may" => [%{"pos" => "verb", "def" => "expressing possibility or permission"}],
    "might" => [%{"pos" => "verb", "def" => "past tense of 'may'; expressing possibility"}],
    "must" => [%{"pos" => "verb", "def" => "be obliged to; expressing necessity or certainty"}],
    "i" => [%{"pos" => "pronoun", "def" => "used by a speaker to refer to himself or herself"}],
    "me" => [
      %{
        "pos" => "pronoun",
        "def" => "used as the object of a verb or preposition to refer to oneself"
      }
    ],
    "my" => [%{"pos" => "determiner", "def" => "belonging to or associated with the speaker"}],
    "mine" => [
      %{"pos" => "pronoun", "def" => "used to refer to something belonging to the speaker"}
    ],
    "myself" => [
      %{"pos" => "pronoun", "def" => "used for emphasis or as the reflexive form of 'I' or 'me'"}
    ],
    "you" => [
      %{"pos" => "pronoun", "def" => "used to refer to the person or people being addressed"}
    ],
    "your" => [
      %{
        "pos" => "determiner",
        "def" => "belonging to or associated with the person being addressed"
      }
    ],
    "yours" => [
      %{
        "pos" => "pronoun",
        "def" => "used to refer to something belonging to the person addressed"
      }
    ],
    "yourself" => [
      %{"pos" => "pronoun", "def" => "used for emphasis or as the reflexive form of 'you'"}
    ],
    "yourselves" => [%{"pos" => "pronoun", "def" => "plural reflexive form of 'you'"}],
    "he" => [
      %{
        "pos" => "pronoun",
        "def" => "used to refer to a male person or animal previously mentioned"
      }
    ],
    "him" => [
      %{
        "pos" => "pronoun",
        "def" => "used as the object of a verb or preposition to refer to a male"
      }
    ],
    "his" => [
      %{"pos" => "determiner", "def" => "belonging to or associated with a male person or animal"}
    ],
    "himself" => [
      %{
        "pos" => "pronoun",
        "def" => "used for emphasis or as the reflexive form of 'he' or 'him'"
      }
    ],
    "she" => [
      %{
        "pos" => "pronoun",
        "def" => "used to refer to a female person or animal previously mentioned"
      }
    ],
    "her" => [
      %{
        "pos" => "pronoun",
        "def" => "used as the object of a verb or preposition to refer to a female"
      }
    ],
    "hers" => [%{"pos" => "pronoun", "def" => "used to refer to something belonging to a female"}],
    "herself" => [
      %{
        "pos" => "pronoun",
        "def" => "used for emphasis or as the reflexive form of 'she' or 'her'"
      }
    ],
    "it" => [
      %{
        "pos" => "pronoun",
        "def" => "used to refer to a thing, animal, or idea previously mentioned"
      }
    ],
    "its" => [
      %{
        "pos" => "determiner",
        "def" => "belonging to or associated with a thing previously mentioned"
      }
    ],
    "itself" => [
      %{"pos" => "pronoun", "def" => "used for emphasis or as the reflexive form of 'it'"}
    ],
    "we" => [%{"pos" => "pronoun", "def" => "used by a speaker to refer to himself and others"}],
    "us" => [
      %{
        "pos" => "pronoun",
        "def" => "used as the object of a verb or preposition to refer to the speaker and others"
      }
    ],
    "our" => [
      %{"pos" => "determiner", "def" => "belonging to or associated with the speaker and others"}
    ],
    "ours" => [
      %{
        "pos" => "pronoun",
        "def" => "used to refer to something belonging to the speaker and others"
      }
    ],
    "ourselves" => [
      %{"pos" => "pronoun", "def" => "used for emphasis or as the reflexive form of 'we' or 'us'"}
    ],
    "they" => [
      %{
        "pos" => "pronoun",
        "def" => "used to refer to people or things previously mentioned or easily identified"
      }
    ],
    "them" => [
      %{
        "pos" => "pronoun",
        "def" => "used as the object of a verb or preposition to refer to people or things"
      }
    ],
    "their" => [
      %{
        "pos" => "determiner",
        "def" => "belonging to or associated with people or things previously mentioned"
      }
    ],
    "theirs" => [
      %{
        "pos" => "pronoun",
        "def" => "used to refer to something belonging to people previously mentioned"
      }
    ],
    "themselves" => [
      %{
        "pos" => "pronoun",
        "def" => "used for emphasis or as the reflexive form of 'they' or 'them'"
      }
    ],
    "who" => [%{"pos" => "pronoun", "def" => "what or which person or people"}],
    "whom" => [
      %{
        "pos" => "pronoun",
        "def" => "used instead of 'who' as the object of a verb or preposition"
      }
    ],
    "whose" => [%{"pos" => "determiner", "def" => "belonging to or associated with which person"}],
    "what" => [%{"pos" => "pronoun", "def" => "asking for information specifying something"}],
    "which" => [
      %{
        "pos" => "determiner",
        "def" => "asking for information specifying one or more from a set"
      }
    ],
    "where" => [%{"pos" => "adverb", "def" => "in or to what place or position"}],
    "when" => [%{"pos" => "adverb", "def" => "at what time; on what occasion"}],
    "why" => [%{"pos" => "adverb", "def" => "for what reason or purpose"}],
    "how" => [%{"pos" => "adverb", "def" => "in what way or manner; by what means"}],
    "to" => [
      %{
        "pos" => "preposition",
        "def" => "expressing motion in the direction of; used with the base form of a verb"
      }
    ],
    "of" => [
      %{"pos" => "preposition", "def" => "expressing the relationship between a part and a whole"}
    ],
    "in" => [%{"pos" => "preposition", "def" => "expressing location inside a place or thing"}],
    "for" => [%{"pos" => "preposition", "def" => "in favor of; having the purpose of"}],
    "on" => [
      %{"pos" => "preposition", "def" => "physically in contact with and supported by a surface"}
    ],
    "with" => [%{"pos" => "preposition", "def" => "accompanied by; in the company of"}],
    "at" => [%{"pos" => "preposition", "def" => "expressing location or time at a point"}],
    "by" => [
      %{
        "pos" => "preposition",
        "def" => "identifying the agent performing an action; near or beside"
      }
    ],
    "from" => [
      %{
        "pos" => "preposition",
        "def" => "indicating the point in space or time at which something starts"
      }
    ],
    "about" => [%{"pos" => "preposition", "def" => "on the subject of; concerning"}],
    "into" => [
      %{"pos" => "preposition", "def" => "expressing movement or direction toward the inside of"}
    ],
    "through" => [%{"pos" => "preposition", "def" => "moving in one side and out the other"}],
    "during" => [%{"pos" => "preposition", "def" => "throughout the course or duration of"}],
    "before" => [%{"pos" => "preposition", "def" => "during the period of time preceding"}],
    "after" => [%{"pos" => "preposition", "def" => "in the time following"}],
    "above" => [%{"pos" => "preposition", "def" => "at a higher level or layer than"}],
    "below" => [%{"pos" => "preposition", "def" => "at a lower level or layer than"}],
    "between" => [
      %{"pos" => "preposition", "def" => "at, into, or across the space separating two things"}
    ],
    "under" => [
      %{"pos" => "preposition", "def" => "extending or directly below; at a lower level than"}
    ],
    "over" => [
      %{"pos" => "preposition", "def" => "extending directly upward from; at a higher level than"}
    ],
    "and" => [%{"pos" => "conjunction", "def" => "used to connect words, clauses, or sentences"}],
    "or" => [%{"pos" => "conjunction", "def" => "used to link alternatives"}],
    "but" => [
      %{
        "pos" => "conjunction",
        "def" => "used to introduce something contrasting with what has been said"
      }
    ],
    "if" => [%{"pos" => "conjunction", "def" => "introducing a conditional clause"}],
    "because" => [%{"pos" => "conjunction", "def" => "for the reason that; since"}],
    "as" => [%{"pos" => "conjunction", "def" => "used in comparisons; while; because"}],
    "than" => [
      %{"pos" => "conjunction", "def" => "used in comparisons to introduce the second element"}
    ],
    "although" => [%{"pos" => "conjunction", "def" => "in spite of the fact that; even though"}],
    "while" => [%{"pos" => "conjunction", "def" => "during the time that; at the same time as"}],
    "since" => [%{"pos" => "conjunction", "def" => "from a time in the past until now; because"}],
    "until" => [%{"pos" => "conjunction", "def" => "up to the point in time when"}],
    "unless" => [
      %{"pos" => "conjunction", "def" => "except if; except under the circumstances that"}
    ],
    "so" => [%{"pos" => "conjunction", "def" => "and for this reason; therefore"}],
    "yet" => [%{"pos" => "conjunction", "def" => "but at the same time; nevertheless"}],
    "not" => [%{"pos" => "adverb", "def" => "used to form negative phrases"}],
    "no" => [%{"pos" => "determiner", "def" => "not any; used to express negation"}],
    "yes" => [%{"pos" => "adverb", "def" => "used to give an affirmative response"}],
    "very" => [%{"pos" => "adverb", "def" => "in a high degree; extremely"}],
    "too" => [%{"pos" => "adverb", "def" => "to a higher degree than is desirable; also"}],
    "also" => [%{"pos" => "adverb", "def" => "in addition; besides"}],
    "just" => [%{"pos" => "adverb", "def" => "exactly; only; simply"}],
    "only" => [%{"pos" => "adverb", "def" => "and no one or nothing more besides"}],
    "even" => [%{"pos" => "adverb", "def" => "used to emphasize something surprising or extreme"}],
    "more" => [%{"pos" => "determiner", "def" => "a greater or additional amount or degree"}],
    "most" => [%{"pos" => "determiner", "def" => "greatest in amount or degree"}],
    "less" => [%{"pos" => "determiner", "def" => "a smaller amount; not as much"}],
    "least" => [%{"pos" => "determiner", "def" => "smallest in amount or degree"}],
    "much" => [%{"pos" => "determiner", "def" => "a large amount; to a great extent"}],
    "many" => [%{"pos" => "determiner", "def" => "a large number of"}],
    "few" => [%{"pos" => "determiner", "def" => "a small number of"}],
    "some" => [%{"pos" => "determiner", "def" => "an unspecified amount or number of"}],
    "any" => [
      %{"pos" => "determiner", "def" => "one or some of a thing or number, no matter which"}
    ],
    "all" => [%{"pos" => "determiner", "def" => "used to refer to the whole quantity or extent"}],
    "each" => [%{"pos" => "determiner", "def" => "every one of two or more people or things"}],
    "every" => [
      %{"pos" => "determiner", "def" => "used to refer to all the individual members of a group"}
    ],
    "both" => [
      %{"pos" => "determiner", "def" => "used to refer to two people or things together"}
    ],
    "either" => [%{"pos" => "determiner", "def" => "one or the other of two people or things"}],
    "neither" => [%{"pos" => "determiner", "def" => "not either; not the one nor the other"}],
    "other" => [
      %{"pos" => "determiner", "def" => "used to refer to a person or thing that is different"}
    ],
    "another" => [%{"pos" => "determiner", "def" => "one more; an additional"}],
    "such" => [
      %{
        "pos" => "determiner",
        "def" => "of the type previously mentioned or about to be mentioned"
      }
    ],
    "same" => [%{"pos" => "determiner", "def" => "identical; not different"}],
    "here" => [%{"pos" => "adverb", "def" => "in, at, or to this place or position"}],
    "there" => [%{"pos" => "adverb", "def" => "in, at, or to that place or position"}],
    "now" => [%{"pos" => "adverb", "def" => "at the present time; immediately"}],
    "then" => [%{"pos" => "adverb", "def" => "at that time; after that; next"}],
    "always" => [%{"pos" => "adverb", "def" => "at all times; on all occasions"}],
    "never" => [%{"pos" => "adverb", "def" => "at no time; not ever"}],
    "often" => [%{"pos" => "adverb", "def" => "frequently; many times"}],
    "sometimes" => [%{"pos" => "adverb", "def" => "occasionally; at times"}],
    "usually" => [%{"pos" => "adverb", "def" => "under normal conditions; generally"}],
    "still" => [
      %{"pos" => "adverb", "def" => "up to and including the present time; nevertheless"}
    ],
    "already" => [%{"pos" => "adverb", "def" => "before or by now or the time in question"}],
    "again" => [%{"pos" => "adverb", "def" => "another time; once more"}],
    "ever" => [%{"pos" => "adverb", "def" => "at any time; at all times"}],
    "well" => [%{"pos" => "adverb", "def" => "in a good or satisfactory way"}],
    "away" => [%{"pos" => "adverb", "def" => "to or at a distance from a place; absent"}],
    "back" => [
      %{
        "pos" => "adverb",
        "def" => "in the opposite direction from which one is facing or traveling"
      }
    ],
    "up" => [%{"pos" => "adverb", "def" => "toward a higher place or position"}],
    "down" => [%{"pos" => "adverb", "def" => "toward or in a lower place or position"}],
    "out" => [%{"pos" => "adverb", "def" => "moving away from a place; not at home"}],
    "off" => [%{"pos" => "adverb", "def" => "away from a place or position; disconnected"}],
    "around" => [%{"pos" => "adverb", "def" => "in or to many places; approximately"}],
    "together" => [
      %{"pos" => "adverb", "def" => "with or in proximity to another person or people"}
    ],
    "apart" => [%{"pos" => "adverb", "def" => "separated by a distance; not together"}],
    "else" => [%{"pos" => "adverb", "def" => "in addition; besides; otherwise"}],
    "instead" => [%{"pos" => "adverb", "def" => "as an alternative or substitute"}],
    "perhaps" => [%{"pos" => "adverb", "def" => "used to express uncertainty or possibility"}],
    "maybe" => [%{"pos" => "adverb", "def" => "perhaps; possibly"}],
    "however" => [
      %{
        "pos" => "adverb",
        "def" => "used to introduce a statement that contrasts with something previously said"
      }
    ],
    "therefore" => [%{"pos" => "adverb", "def" => "for that reason; consequently"}],
    "thus" => [%{"pos" => "adverb", "def" => "as a result; in this way"}],
    "hence" => [%{"pos" => "adverb", "def" => "as a consequence; for this reason"}],
    "anyway" => [%{"pos" => "adverb", "def" => "used to confirm or support a point; regardless"}],
    "rather" => [%{"pos" => "adverb", "def" => "used to indicate preference; to some extent"}],
    "quite" => [%{"pos" => "adverb", "def" => "to the utmost degree; completely; fairly"}],
    "almost" => [%{"pos" => "adverb", "def" => "not quite; very nearly"}],
    "enough" => [%{"pos" => "adverb", "def" => "to the required degree or extent; sufficiently"}],
    "especially" => [
      %{"pos" => "adverb", "def" => "used to single out one thing over all others"}
    ],
    "actually" => [
      %{"pos" => "adverb", "def" => "in fact; really; used to add surprising information"}
    ],
    "really" => [%{"pos" => "adverb", "def" => "in actual fact; very; thoroughly"}],
    "certainly" => [%{"pos" => "adverb", "def" => "used to emphasize something beyond doubt"}],
    "probably" => [
      %{"pos" => "adverb", "def" => "almost certainly; as far as one knows or can tell"}
    ],
    "possibly" => [%{"pos" => "adverb", "def" => "perhaps; used to indicate doubt or hesitation"}],
    "simply" => [%{"pos" => "adverb", "def" => "in a straightforward manner; merely"}],
    "nearly" => [%{"pos" => "adverb", "def" => "very close to; almost"}],
    "finally" => [%{"pos" => "adverb", "def" => "at last; in the end; lastly"}],
    "suddenly" => [%{"pos" => "adverb", "def" => "quickly and unexpectedly"}],
    "recently" => [%{"pos" => "adverb", "def" => "at a recent time; not long ago"}],
    "once" => [%{"pos" => "adverb", "def" => "on one occasion; formerly"}],
    "twice" => [%{"pos" => "adverb", "def" => "two times; on two occasions"}],
    "first" => [%{"pos" => "adverb", "def" => "before anything else; at the beginning"}],
    "last" => [%{"pos" => "adverb", "def" => "on the most recent occasion; after all others"}],
    "next" => [%{"pos" => "adverb", "def" => "immediately afterward; on the next occasion"}],
    "soon" => [%{"pos" => "adverb", "def" => "in or after a short time"}],
    "later" => [%{"pos" => "adverb", "def" => "at a time in the future; after the expected time"}],
    "today" => [%{"pos" => "adverb", "def" => "on this present day; at the present period"}],
    "tomorrow" => [%{"pos" => "adverb", "def" => "on the day after today"}],
    "yesterday" => [%{"pos" => "adverb", "def" => "on the day before today"}]
  }

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Loading target word list...")
    target_words = load_target_words()
    target_set = MapSet.new(target_words)
    Mix.shell().info("Loaded #{length(target_words)} target words")

    Mix.shell().info("\n[1/4] Parsing WordNet data files...")
    wordnet_defs = build_wordnet_definitions(target_set)
    Mix.shell().info("  WordNet direct matches: #{map_size(wordnet_defs)}")

    Mix.shell().info("\n[2/4] Parsing Wordset dictionary files...")
    wordset_defs = build_wordset_definitions(target_set)
    Mix.shell().info("  Wordset matches: #{map_size(wordset_defs)}")

    Mix.shell().info("\n[3/4] Merging definitions...")
    merged = merge_definitions(wordnet_defs, wordset_defs)
    merged = merge_definitions(merged, @function_words)

    Mix.shell().info(
      "  Merged unique words: #{map_size(merged)} (includes #{map_size(@function_words)} function words)"
    )

    Mix.shell().info("\n[4/4] Writing output file...")
    write_output(merged)

    matched = map_size(merged)
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
    @pos_config
    |> Task.async_stream(
      fn {pos, config} -> parse_wordnet_pos(pos, config, target_set) end,
      timeout: :infinity,
      ordered: false
    )
    |> Enum.map(fn {:ok, result} -> result end)
    |> Enum.reduce(%{}, &merge_definitions(&2, &1))
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
    word_offsets = parse_index_file(config.index, target_set)

    word_offsets
    |> Enum.reduce(%{}, fn {word, offsets}, acc ->
      defs = build_word_defs(offsets, synset_map, pos)
      if defs == [], do: acc, else: Map.put(acc, word, defs)
    end)
  end

  defp build_word_defs(offsets, synset_map, pos) do
    offsets
    |> Enum.map(&Map.get(synset_map, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.take(3)
    |> Enum.map(fn def -> %{"pos" => @pos_labels[pos], "def" => def} end)
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
    Path.join(@wordnet_dir, index_file)
    |> File.stream!()
    |> Stream.reject(&String.starts_with?(&1, "  "))
    |> Enum.reduce(%{}, fn line, acc ->
      case parse_index_line(line, target_set) do
        {word, offsets} -> Map.put(acc, word, offsets)
        nil -> acc
      end
    end)
  end

  defp parse_index_line(line, target_set) do
    parts = String.split(line)

    case parts do
      [word | rest] when length(rest) >= 4 ->
        normalized = word |> String.replace("_", " ") |> String.downcase()
        offsets = extract_offsets(rest)

        cond do
          MapSet.member?(target_set, normalized) -> {normalized, offsets}
          MapSet.member?(target_set, word) -> {word, offsets}
          true -> nil
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
