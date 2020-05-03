module Status exposing (Status(..), nextPage)

import PageNumber exposing (PageNumber)


type Status
    = Idle
    | DownloadingActivities PageNumber


nextPage : Status -> Status
nextPage status =
    case status of
        DownloadingActivities pageNumber ->
            DownloadingActivities <| PageNumber.nextPage pageNumber

        _ ->
            status
