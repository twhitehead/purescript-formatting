module Text.Formatting where

import Data.Show as Data.Show
import Control.Semigroupoid (class Semigroupoid)
import Data.Function (($), (<<<))
import Control.Category (identity)
import Data.Semigroup (class Semigroup, (<>))
import Data.Show (class Show)

------------------------------------------------------------
-- Core library.
------------------------------------------------------------

-- | A `String` formatter, like `printf`, but type-safe and composable.
-- |
-- | ### Examples:
-- |
-- | ``` purescript
-- | import Text.Formatting (print, s, string, int)
-- | ```
-- |
-- | Build up a `Format`, composing with `<<<`.
-- | ``` purescript
-- | greeting :: forall r. Format String r (String -> r)
-- | greeting = s "Hello " <<< string <<< s "!"
-- | ```
-- |
-- | Convert it to a function with `print`:
-- | ``` purescript
-- | greet :: String -> String
-- | greet = print greeting
-- | ```
-- |
-- | Then use it:
-- | ``` purescript
-- | message1 :: String
-- | message1 = greet "Kris"
-- | --> message1 == "Hello Kris!"
-- | ```
-- |
-- | Or more often, use it directly:
-- | ``` purescript
-- | message2 :: String
-- | message2 = print greeting "Kris"
-- | --> message2 == "Hello Kris!"
-- | ```
-- |
-- | What really sets this approach apart from string interpolation,
-- | apart from the type-safety, is that we can freely compose
-- | `Format`s. Let's extend `greeting` with some more arguments:
-- | ``` purescript
-- | inbox :: forall r. Format String r (String -> Int -> r)
-- | inbox = greeting <<< s " You have " <<< int <<< s " new messages."
-- | ```
-- |
-- | `print` still makes it into a function:
-- | ``` purescript
-- | welcome :: String -> Int -> String
-- | welcome = print inbox
-- | ```
-- |
-- | Or again, call it in one go:
-- | ``` purescript
-- | message3 :: String
-- | message3 = print inbox "Kris" 3
-- | --> message3 == "Hello Kris! You have 3 new messages."
-- | ```
-- |
-- | ### A Guide To The Types
-- |
-- | As an example, a function that behaves like `printf "%s: %d"`
-- | will have the type signature `Format String r (String -> Int ->
-- | r)`.  This tells you that:
-- |
-- | * `Format String` - This is a `Format` that will eventually yield a `String`.
-- | * `r` - This is there to keep the final argument list of the formatter open.
-- | * `String -> Int -> r)` - The formatter takes a `String`, then
-- | an `Int`, and is open to further extension.

data Format monoid result f
    = Format ((monoid -> result) -> f)

composeFormat ::
  forall r s m f.
  Semigroup m
  => Format m r f
  -> Format m s r
  -> Format m s f
composeFormat (Format f) (Format g) =
  Format (\callback -> f $ \fValue -> g $ \gValue -> callback $ fValue <> gValue)

instance formatSemigroupoid :: Semigroup m => Semigroupoid (Format m) where
  compose = composeFormat

-- | Turns a `Format` into the underlying function it has built up.
-- | Call this when you're ready to apply all the arguments and
-- | generate an `r` (usually a `String`).
print :: forall f r. Format r r f -> f
print (Format format) = format identity

-- | Apply the first argument of the formatter, without unwrapping it
-- | to a plain ol' function.
apply ::
  forall r m a b.
  Format m r (a -> b)
  -> a
  -> Format m r b
apply (Format format) value =
  Format (\callback -> format callback value)

-- | Turn a function into a `Format`.
toFormatter :: forall r m a. (a -> m) -> Format m r (a -> r)
toFormatter f =
  Format (\callback -> callback <<< f)

-- | Modify a `Format` so that this (contravariant) function is called
-- | on its first argument.
-- |
-- | ### Example:
-- | ``` purescript
-- | import Text.Formatting (print, before, int)
-- | print (before length int) [1, 2, 3]
-- | --> "3"
-- | ```
before ::
  forall r m a b f.
  (b -> a)
  -> Format m r (a -> f)
  -> Format m r (b -> f)
before f (Format format) =
  Format (\callback -> format callback <<< f)

-- | Modify a `Format` so that this function is called on its final result.
-- | ### Example:
-- | ``` purescript
-- | import Text.Formatting (print, after, show)
-- | print (after toUpper show) (Just 3)
-- | --> "(JUST 3)"
-- | ```
after :: forall r m n f. (m -> n) -> Format m r f -> Format n r f
after f (Format format) =
  Format (\callback -> format (callback <<< f))

------------------------------------------------------------
-- Formatters.
------------------------------------------------------------

-- | Accept any `Show`able argument.
show :: forall r a. Show a => Format String r (a -> r)
show = Format (\callback value -> callback $ Data.Show.show value)

-- | Accept a `String`.
string :: forall r. Format String r (String -> r)
string = Format (\callback str -> callback str)

-- | Accept an `Int`.
int :: forall r. Format String r (Int -> r)
int = show

-- | Accept a `Number`.
number :: forall r. Format String r (Number -> r)
number = show

-- | Accept a `Boolean`.
boolean :: forall r. Format String r (Boolean -> r)
boolean = show

-- | Insert a fixed string.
s :: forall r. String -> Format String r r
s str = Format (\callback -> callback str)
