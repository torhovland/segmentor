module ActivityTests exposing (suite)

import Activity
import Expect
import Json.Encode as Encode
import Test exposing (Test, describe, test)
import Time


suite : Test
suite =
    describe "The Activity module"
        [ test "can encode to Json" <|
            \_ ->
                { id = Activity.ActivityId 1
                , name = "Foo"
                , time = Time.millisToPosix 0
                , activityType = "type"
                , gearId = Just "gearId"
                , commute = True
                , trainer = True
                , private = True
                }
                    |> Activity.encode
                    |> Encode.encode 4
                    |> String.contains "Foo"
                    |> Expect.true "Expected the encoded activity to contain Foo"
        ]
