defmodule Mosslet.PasswordStrength do
  @moduledoc """
  Password strength checker implementing zxcvbn-style analysis.
  Detects common passwords, keyboard patterns, sequences, repeats, and l33tspeak.
  """

  @basic_common_passwords MapSet.new(~w(
    password 123456 12345678 qwerty abc123 monkey 1234567 letmein trustno1
    dragon baseball iloveyou master sunshine ashley fuckme 123123 654321
    michael shadow 123456789 password1 password123 password12 admin admin123
    login welcome solo passw0rd hello charlie donald master123 welcome1
    football batman soccer princess starwars 696969 superman access mustang
    qwerty123 qwertyuiop 12345 1234567890 111111 qwerty1 qazwsx zxcvbn
    asdfgh asdfghjkl zxcvbnm 1q2w3e4r 1qaz2wsx passw0rd! p@ssword p@ssw0rd
    pass1234 test1234 changeme default secret root guest user temp
    computer internet server database system network security firewall
    spring summer autumn winter january february march april may june july
    august september october november december monday tuesday wednesday
    thursday friday saturday sunday football baseball basketball hockey
    soccer tennis golf swimming running cycling
  ))

  @keyboard_rows [
    "qwertyuiop",
    "asdfghjkl",
    "zxcvbnm",
    "1234567890",
    "!@#$%^&*()"
  ]

  @keyboard_adjacents %{
    "q" => ["w", "a", "1", "2"],
    "w" => ["q", "e", "a", "s", "2", "3"],
    "e" => ["w", "r", "s", "d", "3", "4"],
    "r" => ["e", "t", "d", "f", "4", "5"],
    "t" => ["r", "y", "f", "g", "5", "6"],
    "y" => ["t", "u", "g", "h", "6", "7"],
    "u" => ["y", "i", "h", "j", "7", "8"],
    "i" => ["u", "o", "j", "k", "8", "9"],
    "o" => ["i", "p", "k", "l", "9", "0"],
    "p" => ["o", "l", "0"],
    "a" => ["q", "w", "s", "z"],
    "s" => ["a", "w", "e", "d", "z", "x"],
    "d" => ["s", "e", "r", "f", "x", "c"],
    "f" => ["d", "r", "t", "g", "c", "v"],
    "g" => ["f", "t", "y", "h", "v", "b"],
    "h" => ["g", "y", "u", "j", "b", "n"],
    "j" => ["h", "u", "i", "k", "n", "m"],
    "k" => ["j", "i", "o", "l", "m"],
    "l" => ["k", "o", "p"],
    "z" => ["a", "s", "x"],
    "x" => ["z", "s", "d", "c"],
    "c" => ["x", "d", "f", "v"],
    "v" => ["c", "f", "g", "b"],
    "b" => ["v", "g", "h", "n"],
    "n" => ["b", "h", "j", "m"],
    "m" => ["n", "j", "k"]
  }

  @l33t_substitutions %{
    "4" => "a",
    "@" => "a",
    "8" => "b",
    "(" => "c",
    "<" => "c",
    "3" => "e",
    "6" => "g",
    "9" => "g",
    "#" => "h",
    "!" => "i",
    "1" => "i",
    "|" => "i",
    "0" => "o",
    "$" => "s",
    "5" => "s",
    "+" => "t",
    "7" => "t",
    "2" => "z",
    "%" => "x"
  }

  @guesses_per_second_fast 1.0e10
  @guesses_per_second_slow 1.0e4

  def check(password, user_inputs \\ [])

  def check("", _user_inputs) do
    %{
      score: 0,
      crack_times_display: %{
        offline_fast_hashing_1e10_per_second: "instant",
        offline_slow_hashing_1e4_per_second: "instant"
      }
    }
  end

  def check(password, user_inputs) when is_binary(password) do
    user_inputs = user_inputs |> Enum.reject(&is_nil/1) |> Enum.map(&String.downcase/1)
    password_lower = String.downcase(password)

    matchers = [
      &exact_common_password_match/1,
      &common_password_variation_match/1,
      &keyboard_pattern_match/1,
      &sequence_match/1,
      &repeat_match/1,
      &l33tspeak_match/1,
      &dictionary_match/1,
      &brute_force_match/1
    ]

    matches =
      matchers
      |> Enum.map(fn matcher -> matcher.(password_lower) end)
      |> Enum.filter(fn {guesses, _} -> guesses != :infinity end)

    {base_guesses, match_type} =
      if Enum.empty?(matches) do
        {brute_force_guesses(password), :brute_force}
      else
        Enum.min_by(matches, fn {guesses, _} -> guesses end)
      end

    guesses =
      base_guesses
      |> apply_user_input_penalty(password_lower, user_inputs)
      |> apply_length_bonus(password, match_type)
      |> max(1)

    seconds_fast = guesses / @guesses_per_second_fast
    seconds_slow = guesses / @guesses_per_second_slow

    %{
      score: guesses_to_score(guesses),
      crack_times_display: %{
        offline_fast_hashing_1e10_per_second: format_time(seconds_fast),
        offline_slow_hashing_1e4_per_second: format_time(seconds_slow)
      }
    }
  end

  defp exact_common_password_match(password) do
    if common_password?(password) do
      {10, :common_password}
    else
      {:infinity, nil}
    end
  end

  defp common_password?(password) do
    MapSet.member?(@basic_common_passwords, password) ||
      Password.Policy.CommonPasswords.validate(password, []) ==
        {:error, Password.Policy.CommonPasswords}
  end

  defp common_password_variation_match(password) do
    base = extract_base_password(password)

    if common_password?(base) do
      suffix_guesses = calculate_suffix_guesses(password, base)
      {100 * suffix_guesses, :common_variation}
    else
      {:infinity, nil}
    end
  end

  defp extract_base_password(password) do
    password
    |> String.replace(~r/[0-9!@#$%^&*()]+$/, "")
    |> String.replace(~r/^[0-9!@#$%^&*()]+/, "")
  end

  defp calculate_suffix_guesses(password, base) do
    suffix = String.replace_prefix(password, base, "")
    prefix = String.replace_suffix(password, base <> suffix, "")

    suffix_guesses =
      case suffix do
        "" -> 1
        s when byte_size(s) <= 2 -> 100
        s when byte_size(s) <= 4 -> 1_000
        _ -> 10_000
      end

    prefix_guesses =
      case prefix do
        "" -> 1
        p when byte_size(p) <= 2 -> 100
        _ -> 1_000
      end

    suffix_guesses * prefix_guesses
  end

  defp keyboard_pattern_match(password) do
    row_match = check_keyboard_row_pattern(password)
    walk_match = check_keyboard_walk_pattern(password)

    min_guesses =
      [row_match, walk_match]
      |> Enum.filter(&(&1 != :infinity))
      |> case do
        [] -> :infinity
        matches -> Enum.min(matches)
      end

    {min_guesses, :keyboard_pattern}
  end

  defp check_keyboard_row_pattern(password) do
    min_length = 4

    Enum.reduce_while(@keyboard_rows, :infinity, fn row, acc ->
      reversed_row = String.reverse(row)

      cond do
        String.length(password) >= min_length && String.contains?(row, password) ->
          {:halt, keyboard_row_guesses(String.length(password))}

        String.length(password) >= min_length && String.contains?(reversed_row, password) ->
          {:halt, keyboard_row_guesses(String.length(password)) * 2}

        true ->
          substring_match = find_keyboard_substring(password, row)

          if substring_match != :infinity && substring_match < acc do
            {:cont, substring_match}
          else
            {:cont, acc}
          end
      end
    end)
  end

  defp find_keyboard_substring(password, row) do
    chars = String.graphemes(password)
    len = length(chars)

    if len < 4 do
      :infinity
    else
      4..len
      |> Enum.reduce(:infinity, fn window_size, acc ->
        0..(len - window_size)
        |> Enum.reduce(acc, fn start, inner_acc ->
          substring =
            chars
            |> Enum.slice(start, window_size)
            |> Enum.join()

          if String.contains?(row, substring) || String.contains?(String.reverse(row), substring) do
            guesses = keyboard_row_guesses(window_size) * :math.pow(2, len - window_size)
            min(inner_acc, guesses)
          else
            inner_acc
          end
        end)
      end)
    end
  end

  defp keyboard_row_guesses(length) do
    base = 10 * length
    base * :math.pow(2, max(0, 6 - length))
  end

  defp check_keyboard_walk_pattern(password) do
    chars = String.graphemes(String.downcase(password))

    if length(chars) < 4 do
      :infinity
    else
      walk_length = count_keyboard_walk(chars)

      if walk_length >= 4 && walk_length >= length(chars) * 0.7 do
        walk_length * 100
      else
        :infinity
      end
    end
  end

  defp count_keyboard_walk(chars) do
    chars
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.count(fn [a, b] ->
      adjacents = Map.get(@keyboard_adjacents, a, [])
      b in adjacents
    end)
    |> Kernel.+(1)
  end

  defp sequence_match(password) do
    alpha_seq = check_alpha_sequence(password)
    num_seq = check_numeric_sequence(password)

    min_guesses =
      [alpha_seq, num_seq]
      |> Enum.filter(&(&1 != :infinity))
      |> case do
        [] -> :infinity
        matches -> Enum.min(matches)
      end

    {min_guesses, :sequence}
  end

  defp check_alpha_sequence(password) do
    alphabet = "abcdefghijklmnopqrstuvwxyz"
    reversed = String.reverse(alphabet)

    cond do
      String.length(password) >= 4 && String.contains?(alphabet, password) ->
        sequence_guesses(String.length(password))

      String.length(password) >= 4 && String.contains?(reversed, password) ->
        sequence_guesses(String.length(password)) * 2

      true ->
        check_partial_sequence(password, alphabet)
    end
  end

  defp check_partial_sequence(password, alphabet) do
    chars = String.graphemes(String.downcase(password))
    alpha_chars = Enum.filter(chars, &(&1 =~ ~r/[a-z]/))

    if length(alpha_chars) >= 4 do
      seq_str = Enum.join(alpha_chars)
      reversed = String.reverse(alphabet)

      cond do
        String.contains?(alphabet, seq_str) ->
          sequence_guesses(length(alpha_chars)) *
            :math.pow(10, length(chars) - length(alpha_chars))

        String.contains?(reversed, seq_str) ->
          sequence_guesses(length(alpha_chars)) * 2 *
            :math.pow(10, length(chars) - length(alpha_chars))

        true ->
          :infinity
      end
    else
      :infinity
    end
  end

  defp check_numeric_sequence(password) do
    digits = "0123456789"
    reversed = String.reverse(digits)

    cond do
      String.length(password) >= 4 && String.contains?(digits, password) ->
        sequence_guesses(String.length(password))

      String.length(password) >= 4 && String.contains?(reversed, password) ->
        sequence_guesses(String.length(password)) * 2

      true ->
        check_partial_numeric_sequence(password, digits)
    end
  end

  defp check_partial_numeric_sequence(password, digits) do
    chars = String.graphemes(password)
    digit_chars = Enum.filter(chars, &(&1 =~ ~r/[0-9]/))

    if length(digit_chars) >= 4 do
      seq_str = Enum.join(digit_chars)
      reversed = String.reverse(digits)

      cond do
        String.contains?(digits, seq_str) ->
          sequence_guesses(length(digit_chars)) *
            :math.pow(10, length(chars) - length(digit_chars))

        String.contains?(reversed, seq_str) ->
          sequence_guesses(length(digit_chars)) * 2 *
            :math.pow(10, length(chars) - length(digit_chars))

        true ->
          :infinity
      end
    else
      :infinity
    end
  end

  defp sequence_guesses(length) do
    26 * length * :math.pow(2, max(0, 6 - length))
  end

  defp repeat_match(password) do
    single_repeat = check_single_char_repeat(password)
    pattern_repeat = check_pattern_repeat(password)

    min_guesses =
      [single_repeat, pattern_repeat]
      |> Enum.filter(&(&1 != :infinity))
      |> case do
        [] -> :infinity
        matches -> Enum.min(matches)
      end

    {min_guesses, :repeat}
  end

  defp check_single_char_repeat(password) do
    if String.length(password) >= 3 && Regex.match?(~r/^(.)\1+$/, password) do
      100
    else
      :infinity
    end
  end

  defp check_pattern_repeat(password) do
    len = String.length(password)

    if len >= 6 do
      1..div(len, 2)
      |> Enum.reduce(:infinity, fn pattern_len, acc ->
        pattern = String.slice(password, 0, pattern_len)
        repeated = String.duplicate(pattern, div(len, pattern_len) + 1)

        if String.starts_with?(repeated, password) do
          base_guesses = brute_force_guesses(pattern)
          repeat_count = div(len, pattern_len)
          min(acc, base_guesses * repeat_count)
        else
          acc
        end
      end)
    else
      :infinity
    end
  end

  defp l33tspeak_match(password) do
    decoded = decode_l33tspeak(password)

    if decoded != password do
      if common_password?(decoded) do
        {1_000, :l33tspeak}
      else
        base = extract_base_password(decoded)

        if common_password?(base) do
          {10_000, :l33tspeak_variation}
        else
          {:infinity, nil}
        end
      end
    else
      {:infinity, nil}
    end
  end

  defp decode_l33tspeak(password) do
    password
    |> String.graphemes()
    |> Enum.map(fn char ->
      Map.get(@l33t_substitutions, char, char)
    end)
    |> Enum.join()
    |> String.downcase()
  end

  defp dictionary_match(password) do
    words = extract_words(password)

    if length(words) > 0 do
      guesses =
        words
        |> Enum.map(&word_guesses/1)
        |> Enum.reduce(1, &(&1 * &2))
        |> Kernel.*(word_bonus(length(words)))

      {guesses, :dictionary}
    else
      {:infinity, nil}
    end
  end

  defp extract_words(password) do
    password
    |> String.split(~r/[\s\-_.,!@#$%^&*()+=0-9]+/, trim: true)
    |> Enum.filter(&(String.length(&1) >= 3))
  end

  @common_words MapSet.new(~w(
    the be to of and a in that have it for not on with he as you do at this
    but his by from they we say her she or an will my one all would there
    their what so up out if about who get which go me when make can like time
    no just him know take people into year your good some could them see other
    than then now look only come its over think also back after use two how our
    work first well way even new want because any these give day most us is was
    are been has had have do does did will would should could may might must
    love hate like want need try use help find give take get make know see
    think feel look want come go run walk talk say tell ask answer help
    open close start stop begin end live die eat drink sleep wake work play
    read write learn teach study test pass fail win lose fight run jump
    apple banana cherry orange grape lemon mango peach melon berry fruit
    correct horse battery staple paper clip wire cable desk chair table
    window door wall floor ceiling room house home garden tree flower plant
    water fire earth wind rain snow cloud sun moon star sky ocean river lake
    mountain hill valley forest jungle desert island beach coast shore
    red blue green yellow orange purple pink brown black white gray silver gold
  ))

  defp word_guesses(word) do
    word_lower = String.downcase(word)

    cond do
      common_password?(word_lower) -> 10
      MapSet.member?(@common_words, word_lower) -> 5_000
      String.length(word) <= 4 -> :math.pow(26, String.length(word))
      true -> :math.pow(26, String.length(word)) / 10
    end
  end

  defp word_bonus(count) when count >= 5, do: 100_000
  defp word_bonus(4), do: 10_000
  defp word_bonus(3), do: 100
  defp word_bonus(_), do: 1

  defp brute_force_match(password) do
    {brute_force_guesses(password), :brute_force}
  end

  defp brute_force_guesses(password) do
    length = String.length(password)
    charset_size = calculate_charset_size(password)
    :math.pow(charset_size, length)
  end

  defp calculate_charset_size(password) do
    has_lower = Regex.match?(~r/[a-z]/, password)
    has_upper = Regex.match?(~r/[A-Z]/, password)
    has_digit = Regex.match?(~r/[0-9]/, password)
    has_symbol = Regex.match?(~r/[^a-zA-Z0-9]/, password)

    size = 0
    size = if has_lower, do: size + 26, else: size
    size = if has_upper, do: size + 26, else: size
    size = if has_digit, do: size + 10, else: size
    size = if has_symbol, do: size + 33, else: size

    max(size, 10)
  end

  defp apply_user_input_penalty(guesses, password, user_inputs) do
    penalty =
      Enum.reduce(user_inputs, 1.0, fn input, acc ->
        cond do
          input == "" -> acc
          password == input -> acc * 0.0001
          String.contains?(password, input) -> acc * 0.001
          String.contains?(input, password) -> acc * 0.01
          jaro_similar?(password, input) -> acc * 0.1
          true -> acc
        end
      end)

    guesses * penalty
  end

  defp jaro_similar?(a, b) do
    String.jaro_distance(a, b) > 0.8
  end

  defp apply_length_bonus(guesses, password, match_type) do
    length = String.length(password)

    length_multiplier =
      cond do
        length < 8 -> 0.001
        length < 10 -> 0.01
        length < 12 -> 0.1
        length >= 16 && match_type in [:dictionary, :brute_force] -> 10
        length >= 20 && match_type in [:dictionary, :brute_force] -> 100
        true -> 1
      end

    guesses * length_multiplier
  end

  defp guesses_to_score(guesses) do
    cond do
      guesses < 1.0e3 -> 0
      guesses < 1.0e6 -> 1
      guesses < 1.0e8 -> 2
      guesses < 1.0e10 -> 3
      true -> 4
    end
  end

  defp format_time(seconds) do
    minute = 60
    hour = minute * 60
    day = hour * 24
    month = day * 31
    year = month * 12
    century = year * 100

    cond do
      seconds < 1 -> "less than a second"
      seconds < minute -> "#{round(seconds)} seconds"
      seconds < hour -> "#{round(seconds / minute)} minutes"
      seconds < day -> "#{round(seconds / hour)} hours"
      seconds < month -> "#{round(seconds / day)} days"
      seconds < year -> "#{round(seconds / month)} months"
      seconds < century -> "#{round(seconds / year)} years"
      true -> "centuries"
    end
  end
end
