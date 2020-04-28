module AccessToken exposing (AccessToken(..), toString)


type AccessToken
    = AccessToken String


toString : AccessToken -> String
toString (AccessToken token) =
    token
