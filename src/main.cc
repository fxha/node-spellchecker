#include <cstring>
#include <memory>
#include <vector>
#include <napi.h>
#include "spellchecker.h"

using namespace spellchecker;

namespace {

class Spellchecker : public Napi::ObjectWrap<Spellchecker> {
  private:
    std::unique_ptr<SpellcheckerImplementation> impl;
    Napi::Reference<Napi::Buffer<unsigned char>> dictData;

    Napi::Value SetDictionary(const Napi::CallbackInfo &info);
    Napi::Value IsMisspelled(const Napi::CallbackInfo &info);
    Napi::Value CheckSpelling(const Napi::CallbackInfo &info);
    Napi::Value Add(const Napi::CallbackInfo &info);
    Napi::Value Remove(const Napi::CallbackInfo &info);
    Napi::Value GetSpellcheckerType(const Napi::CallbackInfo &info);

    Napi::Value GetAvailableDictionaries(const Napi::CallbackInfo &info);
    Napi::Value GetCorrectionsForMisspelling(const Napi::CallbackInfo &info);

  public:
    static Napi::Object Init(Napi::Env env, Napi::Object exports);

    Spellchecker(const Napi::CallbackInfo &info):
      Napi::ObjectWrap<Spellchecker>(info),
      impl(SpellcheckerFactory::CreateSpellchecker())
    {}
};

Napi::Value Spellchecker::SetDictionary(const Napi::CallbackInfo &info) {
  auto env = info.Env();

  if (info.Length() < 1 || !info[0].IsString()) {
    throw Napi::TypeError::New(env, "Bad argument");
  }

  bool has_contents = false;
  if (info.Length() > 1) {
    if (!info[1].IsBuffer()) {
      throw Napi::TypeError::New(env, "setDictionary 2nd argument must be a Buffer");
    }

    // NB: We must guarantee that we pin this Buffer
    dictData = Napi::Reference<Napi::Buffer<unsigned char>>::New(info[1].As<Napi::Buffer<unsigned char>>(), 1);
    has_contents = true;
  }

  std::string language = info[0].ToString().Utf8Value();

  bool result;
  if (has_contents) {
    result = impl->SetDictionaryToContents(dictData.Value().Data(), dictData.Value().Length());
  } else {
    result = impl->SetDictionary(language);
  }

  return Napi::Boolean::New(env, result);
}

Napi::Value Spellchecker::IsMisspelled(const Napi::CallbackInfo &info) {
  auto env = info.Env();

  if (info.Length() < 1 || !info[0].IsString()) {
    throw Napi::TypeError::New(env, "Bad argument");
  }

  std::string word = info[0].ToString().Utf8Value();

  return Napi::Boolean::New(env, impl->IsMisspelled(word));
}

Napi::Value Spellchecker::CheckSpelling(const Napi::CallbackInfo &info) {
  auto env = info.Env();

  if (info.Length() < 1 || !info[0].IsString()) {
    throw Napi::TypeError::New(env, "Bad argument");
  }

  std::u16string str = info[0].ToString().Utf16Value();
  if (str.empty()) {
    return Napi::Array::New(env);
  }

  std::vector<MisspelledRange> misspelled_ranges =
      impl->CheckSpelling(reinterpret_cast<const uint16_t *>(str.c_str()), str.size());

  auto result = Napi::Array::New(env, misspelled_ranges.size());
  for (auto iter = misspelled_ranges.begin(); iter != misspelled_ranges.end(); ++iter) {
    size_t index = iter - misspelled_ranges.begin();
    uint32_t start = iter->start, end = iter->end;

    auto misspelled_range = Napi::Object::New(env);
    misspelled_range["start"] = Napi::Number::New(env, start);
    misspelled_range["end"] = Napi::Number::New(env, end);
    result[index] = misspelled_range;
  }

  return result;
}

Napi::Value Spellchecker::Add(const Napi::CallbackInfo &info) {
  auto env = info.Env();

  if (info.Length() < 1 || !info[0].IsString()) {
    throw Napi::TypeError::New(env, "Bad argument");
  }

  std::string word = info[0].ToString().Utf8Value();
  impl->Add(word);

  return env.Undefined();
}

Napi::Value Spellchecker::Remove(const Napi::CallbackInfo &info) {
  auto env = info.Env();

  if (info.Length() < 1 || !info[0].IsString()) {
    throw Napi::TypeError::New(env, "Bad argument");
  }

  std::string word = info[0].ToString().Utf8Value();
  impl->Remove(word);

  return env.Undefined();
}

Napi::Value Spellchecker::GetSpellcheckerType(const Napi::CallbackInfo &info) {
  return Napi::Number::New(info.Env(), impl->GetSpellcheckerType());
}

Napi::Value Spellchecker::GetAvailableDictionaries(const Napi::CallbackInfo &info) {
  auto env = info.Env();

  std::string path = ".";
  if (info.Length() > 0) {
    if (!info[0].IsString()) {
      throw Napi::TypeError::New(env, "Bad argument");
    }
    path = info[0].ToString().Utf8Value();
  }

  std::vector<std::string> dictionaries = impl->GetAvailableDictionaries(path);

  auto result = Napi::Array::New(env, dictionaries.size());
  for (size_t i = 0; i < dictionaries.size(); ++i) {
    auto& dict = dictionaries[i];
    result[i] = Napi::String::New(env, dict);
  }

  return result;
}

Napi::Value Spellchecker::GetCorrectionsForMisspelling(const Napi::CallbackInfo &info) {
  auto env = info.Env();

  if (info.Length() < 1 || !info[0].IsString()) {
    throw Napi::TypeError::New(env, "Bad argument");
  }

  std::string word = info[0].ToString().Utf8Value();
  std::vector<std::string> corrections = impl->GetCorrectionsForMisspelling(word);

  auto result = Napi::Array::New(env, corrections.size());
  for (size_t i = 0; i < corrections.size(); ++i) {
    auto& word = corrections[i];
    result[i] = Napi::String::New(env, word);
  }

  return result;
}

Napi::Object Spellchecker::Init(Napi::Env env, Napi::Object exports) {
  Napi::Function spellcheckerInstance = DefineClass(env, "Spellchecker", {
    InstanceMethod("setDictionary", &Spellchecker::SetDictionary),
    InstanceMethod("getAvailableDictionaries", &Spellchecker::GetAvailableDictionaries),
    InstanceMethod("getCorrectionsForMisspelling", &Spellchecker::GetCorrectionsForMisspelling),
    InstanceMethod("isMisspelled", &Spellchecker::IsMisspelled),
    InstanceMethod("checkSpelling", &Spellchecker::CheckSpelling),
    InstanceMethod("add", &Spellchecker::Add),
    InstanceMethod("remove", &Spellchecker::Remove),
    InstanceMethod("getSpellcheckerType", &Spellchecker::GetSpellcheckerType)
  });

  Napi::FunctionReference* constructor = new Napi::FunctionReference();

  // Create a persistent reference to the class constructor.
  *constructor = Napi::Persistent(spellcheckerInstance);
  exports["Spellchecker"] = spellcheckerInstance;

  // Store the constructor as the add-on instance data.
  env.SetInstanceData<Napi::FunctionReference>(constructor);

  return exports;
}

static Napi::Object Init(Napi::Env env, Napi::Object exports) {
  Spellchecker::Init(env, exports);
  return exports;
}

NODE_API_MODULE(spellchecker, Init);

}  // namespace
