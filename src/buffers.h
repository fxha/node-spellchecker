#ifndef SRC_BUFFERS_H_
#define SRC_BUFFERS_H_

// Translated into UTF-8, this means that a worst-case UTF-16
// buffer would be double (4 bytes).
#define MAX_UTF8_BUFFER 256

// When converting UTF-16 to UTF-8, we still have 1-byte characters
// but it can double the length when going from a wide to two bytes.
#define MAX_UTF16_TO_UTF8_BUFFER MAX_UTF8_BUFFER

#endif // SRC_BUFFERS_H_