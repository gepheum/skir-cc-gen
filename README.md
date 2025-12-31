[![npm](https://img.shields.io/npm/v/skir-cc-gen)](https://www.npmjs.com/package/skir-cc-gen)
[![build](https://github.com/gepheum/skir-cc-gen/workflows/Build/badge.svg)](https://github.com/gepheum/skir-cc-gen/actions)

# Skir's C++ Code Generator

Official plugin for generating C++ code from [.skir](https://github.com/gepheum/skir) files.

Targets C++17 and higher.

## Set up

In your `skir.yml` file, add the following snippet under `generators`:
```yaml
  - mod: skir-cc-gen
    outDir: ./src/skirout
    config:
      writeGoogleTestHeaders: true  # If you  use GoogleTest
```

## Runtime dependencies

The generated C++ code depends on the [skir client library](https://github.com/gepheum/skir-cc-gen/tree/main/client), [absl](https://abseil.io/) and optionally [GoogleTest](https://github.com/google/googletest).

### If you use CMake

Add this to your `CMakeLists.txt`:

```cmake
include(FetchContent)

# Should be ON if writeGoogleTestHeaders is true 
option(BUILD_TESTING "Build tests" OFF)

# Abseil (required, version 20250814.0+)
FetchContent_Declare(
  absl
  GIT_REPOSITORY https://github.com/abseil/abseil-cpp.git
  GIT_TAG        20250814.1  # Use 20250814.0 or later
)
set(ABSL_PROPAGATE_CXX_STD ON)
FetchContent_MakeAvailable(absl)

if(BUILD_TESTING)
  # GoogleTest (optional - only if you use writeGoogleTestHeaders)
  FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG        v1.15.2  # Pick the latest tag
  )
  set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
  FetchContent_MakeAvailable(googletest)
endif()

# skir-client
FetchContent_Declare(
  skir-client
  GIT_REPOSITORY https://github.com/gepheum/skir-cc-gen.git
  GIT_TAG        main  # Or pick a specific commit/tag
  SOURCE_SUBDIR  client
)
FetchContent_MakeAvailable(skir-client)
```

See this [example](https://github.com/gepheum/skir-cc-example/blob/main/CMakeLists.txt).

### If you use Bazel

Refer to this example [BUILD.bazel](https://github.com/gepheum/skir-cc-example/blob/main/BUILD.bazel) file.

## C++ generated code guide

The examples below are for the code generated from [this](https://github.com/gepheum/skir-cc-example/blob/main/skir_src/user.skir) .skir file.

### Referring to generated symbols

Every generated symbol lives in a namespace called `skirout_${path}`,
where `${path}` is the path to the .skir file relative from the root of the
skir source directory, with the ".skir" extension removed, and slashes
replaced with underscores.

```c++
#include "skirout/user.h"

using ::skirout_user::SubscriptionStatus;
using ::skirout_user::User;
using ::skirout_user::UserRegistry;
```

### Constructing structs

```c++
// You can construct a struct like this:
User john;
john.user_id = 42;
john.name = "John Doe";

// Or you can use the designated initialized syntax:
User jane = {
    // Keep fields in alphabetical order
    .name = "Jane Doe",
    .pets = {{
                  .name = "Fluffy",
                  .picture = "cat",
              },
              {
                  .name = "Rex",
                  .picture = "dog",
              }},
    .subscription_status = skirout::kPremium,
    .user_id = 43,
};

// ${Struct}::whole forces you to initialize all the fields of the struct.
// You will get a compile-time error if you miss one.
User lyla = User::whole{
    .name = "Lyla Doe",
    .pets =
        {
            User::Pet::whole{
                .height_in_meters = 0.05f,
                .name = "Tiny",
                .picture = "🐁",
            },
        },
    .quote = "This is Lyla's world, you just live in it",
    .subscription_status = skirout::kFree,
    .user_id = 44,
};
```

### Constructing enums

```c++

// Use skirout::${kFieldName} or ${Enum}::${kFieldName} for constant variants.
SubscriptionStatus john_status = skirout::kFree;
SubscriptionStatus jane_status = skirout::kPremium;
SubscriptionStatus lara_status = SubscriptionStatus::kFree;

// Compilation error: MONDAY is not a field of the SubscriptionStatus enum.
// SubscriptionStatus sara_status = skirout::kMonday;

// Use wrap_${field_name} for wrapper variants.
SubscriptionStatus jade_status =
    skirout::wrap_trial(SubscriptionStatus::Trial({
        .start_time = absl::FromUnixMillis(1743682787000),
    }));
SubscriptionStatus roni_status = SubscriptionStatus::wrap_trial({
    .start_time = absl::FromUnixMillis(1743682787000),
});
```

### Conditions on enums

```c++
if (john_status == skirout::kFree) {
  std::cout << "John, would you like to upgrade to premium?\n";
}

// Call is_${field_name}() to check if the enum holds a wrapper variant.
if (jade_status.is_trial()) {
  // as_${field_name}() returns the wrapped value
  const SubscriptionStatus::Trial& trial = jade_status.as_trial();
  std::cout << "Jade's trial started on " << trial.start_time << "\n";
}

// One way to do an exhaustive switch on an enum.
switch (lara_status.kind()) {
  case SubscriptionStatus::kind_type::kUnknown:
    // UNKNOWN is the default value for an uninitialized SubscriptionStatus.
    // ...
    break;
  case SubscriptionStatus::kind_type::kFreeConst:
    // ...
    break;
  case SubscriptionStatus::kind_type::kPremiumConst:
    // ...
    break;
  case SubscriptionStatus::kind_type::kTrialWrapper: {
    const SubscriptionStatus::Trial& trial = lara_status.as_trial();
    std::cout << "Lara's trial started on " << trial.start_time << "\n";
  }
}

// Another way to do an exhaustive switch using the visitor pattern.
struct Visitor {
  void operator()(skirout::k_unknown) const {
    std::cout << "Lara's subscription status is UNKNOWN\n";
  }
  void operator()(skirout::k_free) const {
    std::cout << "Lara's subscription status is FREE\n";
  }
  void operator()(skirout::k_premium) const {
    std::cout << "Lara's subscription status is PREMIUM\n";
  }
  void operator()(SubscriptionStatus::wrap_trial_type& w) const {
    const SubscriptionStatus::Trial& trial = w.value;
    std::cout << "Lara's trial started on " << trial.start_time << "\n";
  }
};
lara_status.visit(Visitor());
```

### Serialization

Use `ToDenseJson`, `ToReadableJson` or `ToBytes` to serialize a skir value.

```c++
// Serialize a skir value to JSON with ToDenseJson or ToReadableJson.
std::cout << skir::ToDenseJson(john) << "\n";
// [42,"John Doe"]

std::cout << skir::ToReadableJson(john) << "\n";
// {
//   "user_id": 42,
//   "name": "John Doe"
// }

// The dense flavor is the flavor you should pick if you intend to
// deserialize the value in the future. Skir allows fields to be renamed, and
// because fields names are not part of the dense JSON, renaming a field does
// not prevent you from deserializing the value.
// You should pick the readable flavor mostly for debugging purposes.

// The binary format is not human readable, but it is a bit more compact than
// JSON, and serialization/deserialization can be a bit faster.
// Only use it when this small performance gain is likely to matter, which
// should be rare.
std::cout << skir::ToBytes(john).as_string() << "\n";
// skir�+Jane Doe����Fluffy�cat��Rex�dog
```

### Deserialization

Use `Parse` to deserialize a skir value from JSON or binary format.

```c++
absl::StatusOr<User> maybe_john = skir::Parse<User>(skir::ToDenseJson(john));
assert(maybe_john.ok() && *maybe_john == john);
```

### Keyed arrays

A `keyed_items<T, get_key>` is a container that stores items of type T
and allows for fast lookups by key using a hash table.

```c++
UserRegistry user_registry;
skir::keyed_items<User, skirout::get_user_id<>>& users = user_registry.users;
users.push_back(john);
users.push_back(jane);
users.push_back(lyla);

assert(users.size() == 3);
assert(users[0] == john);

const User* maybe_jane = users.find_or_null(43);
assert(maybe_jane != nullptr && *maybe_jane == jane);

assert(users.find_or_default(44).name == "Lyla Doe");
assert(users.find_or_default(45).name == "");

// If multiple items have the same key, find_or_null and find_or_default
// return the last one. Duplicates are allowed but generally discouraged.
User evil_lyla = lyla;
evil_lyla.name = "Evil Lyla";
users.push_back(evil_lyla);
assert(users.find_or_default(44).name == "Evil Lyla");
```

### Equality and hashing

Skir structs and enums are equality comparable and hashable.

```c++
absl::flat_hash_set<User> user_set;
user_set.insert(john);
user_set.insert(jane);
user_set.insert(jane);
user_set.insert(lyla);

assert(user_set.size() == 3);
```

### Constants

```c++
const User& tarzan = skirout_user::k_tarzan();
assert(tarzan.name == "Tarzan");
```

### Skir services

#### Starting a skir service on an HTTP server

Full example [here](https://github.com/gepheum/skir-cc-example/blob/main/service_start.cc).

#### Sending RPCs to a skir service

Full example [here](https://github.com/gepheum/skir-cc-example/blob/main/service_client.cc).

### Dynamic reflection

```c++
using ::skir::reflection::GetTypeDescriptor;
using ::skir::reflection::TypeDescriptor;

// A TypeDescriptor describes a skir type. It contains the definition of all
// the structs and enums referenced from the type.
const TypeDescriptor& user_descriptor = GetTypeDescriptor<User>();

// TypeDescriptor can be serialized/deserialized to/from JSON.

absl::StatusOr<TypeDescriptor> reserialized_type_descriptor =
    TypeDescriptor::FromJson(user_descriptor.AsJson());
assert(reserialized_type_descriptor.ok());
```

### Static reflection

Static reflection allows you to inspect and modify values of generated
skir types in a typesafe manner.

See [string_capitalizer.h](https://github.com/gepheum/skir-cc-example/blob/main/string_capitalizer.h).

```c++
User tarzan_copy = skirout_user::k_tarzan();
// CapitalizeStrings recursively capitalizes all the strings found within a
// skir value.
CapitalizeStrings(tarzan_copy);

std::cout << tarzan_copy << "\n";
// {
//   .user_id: 123,
//   .name: "TARZAN",
//   .quote: "AAAAAAAAAAYAAAAAAAAAAYAAAAAAAAAA",
//   .pets: {
//     {
//       .name: "CHEETA",
//       .height_in_meters: 1.67,
//       .picture: "🐒",
//     },
//   },
//   .subscription_status:
//   ::skirout::wrap_trial_start_time(absl::FromUnixMillis(1743592409000 /*
//   2025-04-02T11:13:29+00:00 */)),
// }
```

### Writing unit tests with GoogleTest

Full example [here](https://github.com/gepheum/skir-cc-example/blob/main/example.test.cc).

#### Struct matchers

```c++
const User john = {
    .name = "John Doe",
    .pets =
        {
            {.height_in_meters = 1.67, .name = "Cheeta", .picture = "🐒"},
        },
    .quote = "Life is like a box of chocolates.",
    .user_id = 42,
};

EXPECT_THAT(john, (StructIs<User>{
                      // Only the specified fields are tested
                      .pets = testing::ElementsAre(StructIs<User::Pet>{
                          .height_in_meters = testing::FloatNear(1.7, 0.1),
                      }),
                      .quote = testing::StartsWith("Life is"),
                      .user_id = 42,
                  }));
```

#### Enum matchers

```c++
SubscriptionStatus john_status = skirout::kFree;

EXPECT_THAT(john_status, testing::Eq(skirout::kFree));

SubscriptionStatus jade_status = SubscriptionStatus::wrap_trial(
    {.start_time = absl::FromUnixMillis(1743682787000)});

EXPECT_THAT(jade_status, IsTrial());
EXPECT_THAT(jade_status, IsTrial(StructIs<SubscriptionStatus::Trial>{
                              .start_time = testing::Gt(absl::UnixEpoch())}));
```
