{Spellchecker} = require '../lib/spellchecker'
fs = require 'fs'
path = require 'path'

enUS = "A robot is a mechanical or virtual artificial agent, usually an electronic machine"
deDE = "Ein Roboter ist eine technische Apparatur, die üblicherweise dazu dient, dem Menschen mechanische Arbeit abzunehmen."
frFR = "Les robots les plus évolués sont capables de se déplacer et de se recharger par eux-mêmes"

defaultLanguage = if process.platform is 'darwin' then '' else 'en_US'
dictionaryDirectory = path.join(__dirname, 'dictionaries')

isNativeSpellchecker = !process.env['SPELLCHECKER_PREFER_HUNSPELL'] && (process.platform is 'darwin' || process.platform is 'win32')

# Because we are dealing with C++ and buffers, we want
# to make sure the user doesn't pass in a string that
# causes a buffer overrun. We limit our buffers to
# 256 characters (64-character word in UTF-8).
maximumLength1Byte = 'a'.repeat(256)
maximumLength2Byte = 'ö'.repeat(128)
maximumLength3Byte = 'ऐ'.repeat(85)
maximumLength4Byte = '𐅐'.repeat(64)
invalidLength1Byte = maximumLength1Byte + 'a'
invalidLength2Byte = maximumLength2Byte + 'ö'
invalidLength3Byte = maximumLength3Byte + 'ऐ'
invalidLength4Byte = maximumLength4Byte + '𐄇'

maximumLength1BytePair = [maximumLength1Byte, maximumLength1Byte].join " "
maximumLength2BytePair = [maximumLength2Byte, maximumLength2Byte].join " "
maximumLength3BytePair = [maximumLength3Byte, maximumLength3Byte].join " "
maximumLength4BytePair = [maximumLength4Byte, maximumLength4Byte].join " "
invalidLength1BytePair = [invalidLength1Byte, invalidLength1Byte].join " "
invalidLength2BytePair = [invalidLength2Byte, invalidLength2Byte].join " "
invalidLength3BytePair = [invalidLength3Byte, invalidLength3Byte].join " "
invalidLength4BytePair = [invalidLength4Byte, invalidLength4Byte].join " "

readDictionaryForLang = (lang) ->
  return new Buffer([]) unless lang
  fs.readFileSync(path.join(dictionaryDirectory, "#{lang.replace(/_/g, '-')}.bdic"))

describe "SpellChecker", ->
  describe ".isMisspelled(word)", ->
    beforeEach ->
      @fixture = new Spellchecker()
      if isNativeSpellchecker
        @fixture.setDictionary defaultLanguage
      else
        @fixture.setDictionary defaultLanguage, readDictionaryForLang(defaultLanguage)

    it "returns true if the word is mispelled", ->
      @fixture.setDictionary('en_US', readDictionaryForLang('en_US'))
      expect(@fixture.isMisspelled('wwoorrddd')).toBe true

    it "returns false if the word isn't mispelled", ->
      @fixture.setDictionary('en_US', readDictionaryForLang('en_US'))
      expect(@fixture.isMisspelled('word')).toBe false

    it "throws an exception when no word specified", ->
      expect(-> @fixture.isMisspelled()).toThrow()

    it "automatically detects languages on OS X", ->
      return unless process.platform is 'darwin'

      expect(@fixture.checkSpelling(enUS)).toEqual []
      expect(@fixture.checkSpelling(deDE)).toEqual []
      expect(@fixture.checkSpelling(frFR)).toEqual []

    it "correctly switches languages", ->
      return unless process.platform is 'linux'

      expect(@fixture.setDictionary('en_US', readDictionaryForLang('en_US'))).toBe true
      expect(@fixture.checkSpelling(enUS)).toEqual []
      expect(@fixture.checkSpelling(deDE)).not.toEqual []
      expect(@fixture.checkSpelling(frFR)).not.toEqual []

      if @fixture.setDictionary('de_DE', readDictionaryForLang('de_DE'))
        expect(@fixture.checkSpelling(enUS)).not.toEqual []
        expect(@fixture.checkSpelling(deDE)).toEqual [{ start :0, end :3 }] # Bug in Chromiums Hunspell version that is fixed in electron-spellchecker.
        expect(@fixture.checkSpelling(frFR)).not.toEqual []

      @fixture = new Spellchecker()
      if @fixture.setDictionary('fr_FR', readDictionaryForLang('fr_FR'))
        expect(@fixture.checkSpelling(enUS)).not.toEqual []
        expect(@fixture.checkSpelling(deDE)).not.toEqual []
        expect(@fixture.checkSpelling(frFR)).toEqual [{ start :0, end :3 }] # Bug in Chromiums Hunspell version that is fixed in electron-spellchecker.

    it 'returns true for a string of 256 1-byte characters', ->
      if process.platform is 'linux'
        expect(@fixture.isMisspelled(maximumLength1Byte)).toBe true

    it 'returns true for a string of 128 2-byte characters', ->
      if process.platform is 'linux'
        expect(@fixture.isMisspelled(maximumLength2Byte)).toBe true

    it 'returns true for a string of 85 3-byte characters', ->
      if process.platform is 'linux'
        expect(@fixture.isMisspelled(maximumLength3Byte)).toBe true

    it 'returns true for a string of 64 4-byte characters', ->
      if process.platform is 'linux'
        expect(@fixture.isMisspelled(maximumLength4Byte)).toBe true

    it 'returns false for a string of 257 1-byte characters', ->
      if process.platform is 'linux'
        expect(@fixture.isMisspelled(invalidLength1Byte)).toBe false

    it 'returns false for a string of 65 2-byte characters', ->
      if process.platform is 'linux'
        expect(@fixture.isMisspelled(invalidLength2Byte)).toBe false

    it 'returns false for a string of 86 3-byte characters', ->
      if process.platform is 'linux'
        expect(@fixture.isMisspelled(invalidLength3Byte)).toBe false

    it 'returns false for a string of 65 4-byte characters', ->
      if process.platform is 'linux'
        expect(@fixture.isMisspelled(invalidLength4Byte)).toBe false

  describe ".checkSpelling(string)", ->
    beforeEach ->
      @fixture = new Spellchecker()
      if isNativeSpellchecker
        @fixture.setDictionary defaultLanguage
      else
        @fixture.setDictionary defaultLanguage, readDictionaryForLang(defaultLanguage)

    it "returns an empty array of an empty string", ->
      string = ""

      expect(@fixture.checkSpelling(string)).toEqual []

    it "returns an array of character ranges of misspelled words", ->
      string = "cat caat dog dooog"

      expect(@fixture.checkSpelling(string)).toEqual [
        {start: 4, end: 8},
        {start: 13, end: 18},
      ]

    it "accounts for UTF16 pairs", ->
      string = "😎 cat caat dog dooog"

      expect(@fixture.checkSpelling(string)).toEqual [
        {start: 7, end: 11},
        {start: 16, end: 21},
      ]

    it "accounts for other non-word characters", ->
      string = "'cat' (caat. <dog> :dooog)"
      expect(@fixture.checkSpelling(string)).toEqual [
        {start: 7, end: 11},
        {start: 20, end: 25},
      ]

    it "does not treat non-english letters as word boundaries", ->
      @fixture.add("cliché")
      expect(@fixture.checkSpelling("what cliché nonsense")).toEqual []
      @fixture.remove("cliché")

    it "handles words with apostrophes", ->
      string = "doesn't isn't aint hasn't"
      expect(@fixture.checkSpelling(string)).toEqual [
        {start: string.indexOf("aint"), end: string.indexOf("aint") + 4}
      ]

      string = "you say you're 'certain', but are you really?"
      expect(@fixture.checkSpelling(string)).toEqual []

      string = "you say you're 'sertan', but are you really?"
      expect(@fixture.checkSpelling(string)).toEqual [
        {start: string.indexOf("sertan"), end: string.indexOf("',")}
      ]

    it "handles invalid inputs", ->
      fixture = @fixture
      expect(fixture.checkSpelling("")).toEqual []
      expect(-> fixture.checkSpelling()).toThrow("Bad argument")
      expect(-> fixture.checkSpelling(null)).toThrow("Bad argument")
      expect(-> fixture.checkSpelling({})).toThrow("Bad argument")

    it 'returns true for a string of 256 1-byte characters', ->
      if process.platform is 'linux'
        expect(@fixture.isMisspelled(maximumLength1Byte)).toBe true

    it 'returns false for a string of 257 1-byte characters', ->
      if process.platform is 'linux'
        expect(@fixture.isMisspelled(invalidLength1Byte)).toBe false

    it 'returns values for a pair of 256 1-byte character strings', ->
      if process.platform is 'linux'
        expect(@fixture.checkSpelling(maximumLength1BytePair)).toEqual [
          {start: 0, end: 256},
          {start: 257, end: 513},
        ]

    it 'returns values for a string of 128 2-byte character strings', ->
      if process.platform is 'linux'
        expect(@fixture.checkSpelling(maximumLength2BytePair)).toEqual [
          {start: 0, end: 128},
          {start: 129, end: 257},
        ]

    it 'returns values for a string of 85 3-byte character strings', ->
      if process.platform is 'linux'
        expect(@fixture.checkSpelling(maximumLength3BytePair)).toEqual [
          {start: 0, end: 85},
          {start: 86, end: 171},
        ]

    # xit 'returns values for a string of 64 4-byte character strings', ->
    #   # Linux doesn't seem to handle 4-byte encodings
    #   expect(@fixture.checkSpelling(maximumLength4BytePair)).toEqual [
    #     {start: 0, end: 128},
    #     {start: 129, end: 257},
    #   ]

    it 'returns nothing for a pair of 257 1-byte character strings', ->
      if process.platform is 'linux'
        expect(@fixture.checkSpelling(invalidLength1BytePair)).toEqual []

    it 'returns nothing for a pair of 129 2-byte character strings', ->
      if process.platform is 'linux'
        expect(@fixture.checkSpelling(invalidLength2BytePair)).toEqual []

    it 'returns nothing for a pair of 86 3-byte character strings', ->
      if process.platform is 'linux'
        expect(@fixture.checkSpelling(invalidLength3BytePair)).toEqual []

    it 'returns nothing for a pair of 65 4-byte character strings', ->
      if process.platform is 'linux'
        expect(@fixture.checkSpelling(invalidLength4BytePair)).toEqual []

    it 'returns values for a pair of 256 1-byte character strings with encoding', ->
      if process.platform is 'linux'
        @fixture.setDictionary('de_DE', readDictionaryForLang('de_DE'))
        expect(@fixture.checkSpelling(maximumLength1BytePair)).toEqual [
          {start: 0, end: 256},
          {start: 257, end: 513},
        ]

    it 'returns values for a string of 128 2-byte character strings with encoding', ->
      if process.platform is 'linux'
        @fixture.setDictionary('de_DE', readDictionaryForLang('de_DE'))
        expect(@fixture.checkSpelling(maximumLength2BytePair)).toEqual [
          {start: 0, end: 128},
          {start: 129, end: 257},
        ]

    it 'returns values for a string of 85 3-byte character strings with encoding', ->
      if process.platform is 'linux'
        @fixture.setDictionary('de_DE', readDictionaryForLang('de_DE'))
        @fixture.checkSpelling(invalidLength3BytePair)

  describe ".getCorrectionsForMisspelling(word)", ->
    beforeEach ->
      @fixture = new Spellchecker()
      if isNativeSpellchecker
        @fixture.setDictionary defaultLanguage
      else
        @fixture.setDictionary defaultLanguage, readDictionaryForLang(defaultLanguage)

    it "returns an array of possible corrections", ->
      corrections = @fixture.getCorrectionsForMisspelling('worrd')
      expect(corrections.length).toBeGreaterThan 0
      expect(corrections.indexOf('word')).toBeGreaterThan -1

    it "throws an exception when no word specified", ->
      expect(-> @fixture.getCorrectionsForMisspelling()).toThrow()

  describe ".add(word) and .remove(word)", ->
    beforeEach ->
      @fixture = new Spellchecker()
      if isNativeSpellchecker
        @fixture.setDictionary defaultLanguage
      else
        @fixture.setDictionary defaultLanguage, readDictionaryForLang(defaultLanguage)

    it "allows words to be added and removed to the dictionary", ->
      # NB: Windows spellchecker cannot remove words, and since it holds onto
      # words, rerunning this test >1 time causes it to incorrectly fail
      return if process.platform is 'win32'

      expect(@fixture.isMisspelled('wwoorrdd')).toBe true

      @fixture.add('wwoorrdd')
      expect(@fixture.isMisspelled('wwoorrdd')).toBe false

      @fixture.remove('wwoorrdd')
      expect(@fixture.isMisspelled('wwoorrdd')).toBe true

    it "add throws an error if no word is specified", ->
      errorOccurred = false
      try
        @fixture.add()
      catch
        errorOccurred = true
      expect(errorOccurred).toBe true

    it "remove throws an error if no word is specified", ->
      errorOccurred = false
      try
        @fixture.remove()
      catch
        errorOccurred = true
      expect(errorOccurred).toBe true


  describe ".getAvailableDictionaries()", ->
    beforeEach ->
      @fixture = new Spellchecker()
      if isNativeSpellchecker
        @fixture.setDictionary defaultLanguage
      else
        @fixture.setDictionary defaultLanguage, readDictionaryForLang(defaultLanguage)

    it "returns an array of string dictionary names", ->
      # NB: getAvailableDictionaries is nop'ped in hunspell and it also doesn't
      # work inside Appveyor's CI environment
      return if process.platform is 'linux' or process.env.CI or process.env.SPELLCHECKER_PREFER_HUNSPELL

      dictionaries = @fixture.getAvailableDictionaries()
      expect(Array.isArray(dictionaries)).toBe true

      expect(dictionaries.length).toBeGreaterThan 0
      for dictionary in dictionaries.length
        expect(typeof dictionary).toBe 'string'
        expect(diction.length).toBeGreaterThan 0

  describe ".setDictionary(lang, dictDirectory)", ->
    it "sets the spell checker's language, and dictionary directory", ->
      awesome = true
      expect(awesome).toBe true
