#include <cstdio>
#include <cwctype>
#include <clocale>
#include <algorithm>
#include "../vendor/hunspell/src/hunspell/hunspell.hxx"
#include "spellchecker_hunspell.h"
#include "buffers.h"

namespace spellchecker {

HunspellSpellchecker::HunspellSpellchecker() : hunspell(NULL), transcoder(NewTranscoder()) { }

HunspellSpellchecker::~HunspellSpellchecker() {
  if (hunspell) {
    delete hunspell;
  }

  if (transcoder) {
    FreeTranscoder(transcoder);
  }
}

bool HunspellSpellchecker::SetDictionary(const std::string& language) {
  if (hunspell) {
    delete hunspell;
    hunspell = NULL;
  }
  
  return false; 
}

bool HunspellSpellchecker::SetDictionaryToContents(const unsigned char* data, size_t length) {
  if (hunspell) {
    delete hunspell;
    hunspell = NULL;
  }

  hunspell = new Hunspell(data, length);
  return true;
}

std::vector<std::string> HunspellSpellchecker::GetAvailableDictionaries(const std::string& path) {
  return std::vector<std::string>();
}

bool HunspellSpellchecker::IsMisspelled(const std::string& word) {
  if (!hunspell) {
    return false;
  }

  // If the word is too long, then don't do anything.
  if (word.length() > MAX_UTF8_BUFFER) {
    return false;
  }

  return hunspell->spell(word.c_str()) == 0;
}

std::vector<MisspelledRange> HunspellSpellchecker::CheckSpelling(const uint16_t *utf16_text, size_t utf16_length) {
  std::vector<MisspelledRange> result;

  if (!hunspell || !transcoder) {
    return result;
  }

  std::vector<char> utf8_buffer(MAX_UTF16_TO_UTF8_BUFFER);

  enum {
    unknown,
    in_separator,
    in_word,
  } state = in_separator;

  // Because all of the strings are UTF-8 because we got them from Chromium that
  // way, we need to make sure our iswalpha works on UTF-8 strings. We picked a
  // generic locale because we don't pass the locale in. Sadly, "C.utf8" doesn't
  // work so we assume that US English is available everywhere.
  setlocale(LC_CTYPE, "en_US.UTF-8");

  // Go through the UTF-16 characters and look for breaks.
  size_t word_start = 0, i = 0;
  for (; i < utf16_length; ++i) {
    uint16_t c = utf16_text[i];

    switch (state) {
      case unknown:
        if (iswpunct(c) || iswspace(c)) {
          state = in_separator;
        }
        break;

      case in_separator:
        if (iswalpha(c)) {
          word_start = i;
          state = in_word;
        } else if (!iswpunct(c) && !iswspace(c)) {
          state = unknown;
        }
        break;

      case in_word:
        if (c == '\'' && iswalpha(utf16_text[i + 1])) {
          ++i;
        } else if (c == 0 || iswpunct(c) || iswspace(c)) {
          state = in_separator;
          bool converted = TranscodeUTF16ToUTF8(transcoder, (char *)utf8_buffer.data(), utf8_buffer.size(), utf16_text + word_start, i - word_start);
          if (converted) {
            if (hunspell->spell(utf8_buffer.data()) == 0) {
              MisspelledRange range;
              range.start = word_start;
              range.end = i;
              result.push_back(range);
            }
          }
        } else if (!iswalpha(c)) {
          state = unknown;
        }
        break;
    }
  }

  // Allow strings that doesn't end with \0 or 0x00.
  if (state == in_word) {
    bool converted = TranscodeUTF16ToUTF8(transcoder, (char *)utf8_buffer.data(), utf8_buffer.size(), utf16_text + word_start, i - word_start);
    if (converted) {
      if (hunspell->spell(utf8_buffer.data()) == 0) {
        MisspelledRange range;
        range.start = word_start;
        range.end = i;
        result.push_back(range);
      }
    }
  }

  return result;
}

void HunspellSpellchecker::Add(const std::string& word) {
  if (hunspell) {
    hunspell->add(word.c_str());
  }
}

void HunspellSpellchecker::Remove(const std::string& word) {
  if (hunspell) {
    hunspell->remove(word.c_str());
  }
}

uint32_t HunspellSpellchecker::GetSpellcheckerType() {
  return 0;
}

std::vector<std::string> HunspellSpellchecker::GetCorrectionsForMisspelling(const std::string& word) {
  std::vector<std::string> corrections;

  if (hunspell) {
    char** slist;
    int size = hunspell->suggest(&slist, word.c_str());

    corrections.reserve(size);
    for (int i = 0; i < size; ++i) {
      corrections.push_back(slist[i]);
    }

    hunspell->free_list(&slist, size);
  }
  return corrections;
}

}  // namespace spellchecker
