// Tiny read-only JSON parser: enough for the NR/SR manifests and fixtures.
#pragma once
#include <cstdlib>
#include <map>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace json {

struct Value {
  enum Kind { Null, Bool, Number, String, Array, Object } kind = Null;
  bool boolean = false;
  double number = 0;
  std::string string;
  std::vector<Value> array;
  std::map<std::string, Value> object;

  const Value& operator[](const std::string& key) const {
    auto it = object.find(key);
    if (it == object.end()) throw std::runtime_error("missing JSON key " + key);
    return it->second;
  }
  const Value& operator[](size_t index) const {
    if (index >= array.size()) throw std::runtime_error("JSON index out of range");
    return array[index];
  }
  bool has(const std::string& key) const { return object.count(key) != 0; }
  int64_t integer() const { return (int64_t)number; }
  const std::string& str() const { return string; }
  size_t size() const { return kind == Array ? array.size() : object.size(); }
};

class Parser {
 public:
  explicit Parser(const std::string& text) : text_(text) {}
  Value parse() {
    Value value = parseValue();
    skipSpace();
    if (position_ != text_.size()) fail("trailing characters");
    return value;
  }

 private:
  void fail(const char* what) { throw std::runtime_error(std::string("JSON: ") + what + " at " + std::to_string(position_)); }
  void skipSpace() { while (position_ < text_.size() && isspace((unsigned char)text_[position_])) ++position_; }
  char peek() { skipSpace(); return position_ < text_.size() ? text_[position_] : '\0'; }
  void expect(char c) { if (peek() != c) fail("unexpected character"); ++position_; }
  Value parseValue() {
    char c = peek();
    Value value;
    if (c == '{') {
      value.kind = Value::Object;
      ++position_;
      if (peek() == '}') { ++position_; return value; }
      while (true) {
        std::string key = parseString();
        expect(':');
        value.object[key] = parseValue();
        char next = peek();
        ++position_;
        if (next == '}') break;
        if (next != ',') fail("expected , or }");
      }
    } else if (c == '[') {
      value.kind = Value::Array;
      ++position_;
      if (peek() == ']') { ++position_; return value; }
      while (true) {
        value.array.push_back(parseValue());
        char next = peek();
        ++position_;
        if (next == ']') break;
        if (next != ',') fail("expected , or ]");
      }
    } else if (c == '"') {
      value.kind = Value::String;
      value.string = parseString();
    } else if (c == 't' || c == 'f') {
      value.kind = Value::Bool;
      value.boolean = c == 't';
      position_ += value.boolean ? 4 : 5;
    } else if (c == 'n') {
      position_ += 4;
    } else {
      value.kind = Value::Number;
      const char* start = text_.c_str() + position_;
      char* end = nullptr;
      value.number = strtod(start, &end);
      if (end == start) fail("bad number");
      position_ += (size_t)(end - start);
    }
    return value;
  }
  std::string parseString() {
    expect('"');
    std::string result;
    while (position_ < text_.size()) {
      char c = text_[position_++];
      if (c == '"') return result;
      if (c == '\\') {
        char escape = text_[position_++];
        switch (escape) {
          case 'n': result += '\n'; break;
          case 't': result += '\t'; break;
          case 'r': result += '\r'; break;
          case 'b': result += '\b'; break;
          case 'f': result += '\f'; break;
          case 'u': {
            unsigned code = (unsigned)strtoul(text_.substr(position_, 4).c_str(), nullptr, 16);
            position_ += 4;
            if (code < 0x80) result += (char)code;
            else if (code < 0x800) { result += (char)(0xc0 | (code >> 6)); result += (char)(0x80 | (code & 0x3f)); }
            else { result += (char)(0xe0 | (code >> 12)); result += (char)(0x80 | ((code >> 6) & 0x3f)); result += (char)(0x80 | (code & 0x3f)); }
            break;
          }
          default: result += escape;
        }
      } else {
        result += c;
      }
    }
    fail("unterminated string");
    return result;
  }
  const std::string& text_;
  size_t position_ = 0;
};

inline Value parse(const std::string& text) { return Parser(text).parse(); }

}  // namespace json
