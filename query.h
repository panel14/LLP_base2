#include <stdint.h>

#define STRING_TYPE 0
#define INT_TYPE 1
#define FLOAT_TYPE 2

#define VS_SIZE sizeof(struct valueSetting)
#define EXTEND_COMP_SIZE sizeof(struct extendedComparator)
#define FILTER_SIZE sizeof(struct filter)
#define COMP_SIZE sizeof(struct comparator)

struct query {
	uint8_t command;
	struct filter* filtersList;
	struct valueSetting* settingsList;
};

struct filter {
	struct filter* next;
	struct comparator* compList;
};

struct keyValuePair {
	char* key;
	uint8_t valueType;
	uint64_t valueInt;
	float valueReal;
};

struct comparator {
	struct comparator* next;
	uint8_t opCode;
	struct keyValuePair kv;
};

//chained
struct extendedComparator {
	struct extendedComparator* next;
	struct extendedComparator* connected;
	uint8_t opCode;
	struct keyValuePair kv;
};

struct valueSetting {
	struct valueSetting* next;
	struct keyValuePair* kv;
};
