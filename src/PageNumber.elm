module PageNumber exposing (PageNumber(..), nextPage, toString)


type PageNumber
    = FirstPage
    | PageNumber Int


nextPage : PageNumber -> PageNumber
nextPage pageNumber =
    case pageNumber of
        FirstPage ->
            PageNumber 1

        PageNumber a ->
            PageNumber <| a + 1


toString : PageNumber -> String
toString pageNumber =
    case pageNumber of
        FirstPage ->
            "0"

        PageNumber a ->
            String.fromInt a
