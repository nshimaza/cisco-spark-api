{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE OverloadedStrings #-}

module Network.CiscoSpark
    (
    -- * Types
      Authorization (..)

    , Person (..)
    , PersonId (..)
    , Email (..)
    , DisplayName (..)
    , NickName (..)
    , FirstName (..)
    , LastName (..)
    , AvatarUrl (..)
    , OrganizationId (..)
    , RoleId (..)
    , LicenseId (..)
    , Timezone (..)
    , PersonStatus (..)
    , PersonType (..)
    , PersonList (..)
    , CreatePerson (..)
    , UpdatePerson (..)

    , Room (..)
    , RoomId (..)
    , RoomTitle (..)
    , RoomType (..)
    , RoomList (..)
    , CreateRoom (..)
    , UpdateRoom (..)

    , Membership (..)
    , MembershipId (..)
    , MembershipList (..)
    , CreateMembership (..)
    , UpdateMembership (..)

    , Message (..)
    , MessageId (..)
    , MessageText (..)
    , MessageHtml (..)
    , MessageMarkdown (..)
    , FileUrl (..)
    , MessageList (..)
    , CreateMessage (..)

    , TeamName (..)
    , TeamId (..)
    , Team (..)
    , TeamList (..)
    , CreateTeam (..)
    , UpdateTeam (..)

    , TeamMembership (..)
    , TeamMembershipId (..)
    , TeamMembershipList (..)
    , CreateTeamMembership (..)
    , UpdateTeamMembership (..)

    , Organization (..)
    , OrganizationDisplayName (..)
    , OrganizationList (..)

    , License (..)
    , LicenseDisplayName (..)
    , LicenseUnit (..)
    , LicenseList (..)

    , Role (..)
    , RoleName (..)
    , RoleList (..)

    , Timestamp (..)
    -- * Functions
    , streamPersonList
    , getPersonDetail
    , getPersonDetailEither
    , streamTeamList
    , getTeamDetailEither
    , getTeamDetail
    , ciscoSparkBaseRequest
    ) where

import           Conduit
import           Data.Aeson                  (FromJSON)
import           Data.ByteString             (ByteString)
import           Data.ByteString.Char8        as C8 (unpack)
import           Data.Monoid                 ((<>))
import           Data.Text                   (Text)
import           Data.Text.Encoding          (encodeUtf8)
import           Network.HTTP.Simple

import           Network.CiscoSpark.Internal
import           Network.CiscoSpark.Types








-- | Authorization string against Spark API to be contained in HTTP Authorization header of every request.
newtype Authorization = Authorization ByteString deriving (Eq, Show)

makeReqPath :: ByteString -> ByteString
makeReqPath path = "/v1/" <> path

-- | Common part of 'Request' against Spark API.
ciscoSparkBaseRequest :: Request
ciscoSparkBaseRequest
    = addRequestHeader "Content-Type" "application/json; charset=utf-8"
    $ setRequestPort 443
    $ setRequestHost "api.ciscospark.com"
    $ setRequestSecure True
    $ defaultRequest

addAuthorizationHeader :: Authorization -> Request -> Request
addAuthorizationHeader (Authorization auth) = addRequestHeader "Authorization" ("Bearer " <> auth)




hasNextRel :: [(LinkParam, ByteString)] -> Bool
hasNextRel = any (\(param, str) -> param == Rel && str == "next")

isNextRel :: LinkHeader -> Bool
isNextRel = hasNextRel . linkHeaderParams



-- | Building common part of 'Request' for List APIs.
makeCommonListReq
    :: Request      -- ^ Common request components
    -> ByteString   -- ^ API category part of REST URL path
    -> Request
makeCommonListReq base path = setRequestPath ("/v1/" <> path)
                            $ setRequestMethod "GET"
                            $ base

{-|
    Common worker function for List APIs.
    It accesses List API with given 'Request', unwrap result into list of items, stream them to Conduit pipe
    and finally it automatically accesses next page designated via HTTP Link header if available.
-}
streamList :: (MonadIO m, SparkListItem i) => Authorization -> Request -> Source m i
streamList auth req = do
    res <- httpJSON $ addAuthorizationHeader auth req
    yieldMany . unwrap $ getResponseBody res
    streamListLoop auth res

streamListLoop :: (MonadIO m, FromJSON a, SparkListItem i) => Authorization -> Response a -> Source m i
streamListLoop auth res = case getNextUrl res of
    Nothing     -> pure ()
    Just url    -> case parseRequest $ "GET " <> (C8.unpack url) of
        Nothing         -> pure ()
        Just nextReq    -> do
            nextRes <- httpJSON $ addAuthorizationHeader auth nextReq
            yieldMany . unwrap $ getResponseBody nextRes
            streamListLoop auth nextRes

streamTeamList :: MonadIO m => Authorization -> Request -> Source m Team
streamTeamList auth base = streamList auth $ makeCommonListReq base "teams"

streamPersonList :: MonadIO m => Authorization -> Request -> Source m Person
streamPersonList auth base = streamList auth $ makeCommonListReq base "people"


makeCommonDetailReq
    :: Request          -- ^ Common request components.
    -> Authorization    -- ^ Authorization string against Spark API.
    -> ByteString       -- ^ API category part of REST URL path.
    -> Text             -- ^ Identifier string part of REST URL path.
    -> Request
makeCommonDetailReq base auth path idStr
    = setRequestPath ("/v1/" <> path <> "/" <> encodeUtf8 idStr)
    $ setRequestMethod "GET"
    $ addAuthorizationHeader auth
    $ base

getTeamDetail :: MonadIO m => Request -> Authorization -> TeamId -> m (Response Team)
getTeamDetail base auth (TeamId idStr) = httpJSON $ makeCommonDetailReq base auth "teams" idStr

getTeamDetailEither :: MonadIO m => Request -> Authorization -> TeamId -> m (Response (Either JSONException Team))
getTeamDetailEither base auth (TeamId idStr) = httpJSONEither $ makeCommonDetailReq base auth "teams" idStr

getPersonDetail :: MonadIO m => Request -> Authorization -> PersonId -> m (Response Person)
getPersonDetail base auth (PersonId idStr) = httpJSON $ makeCommonDetailReq base auth "people" idStr

getPersonDetailEither :: MonadIO m => Request -> Authorization -> PersonId -> m (Response (Either JSONException Person))
getPersonDetailEither base auth (PersonId idStr) = httpJSONEither $ makeCommonDetailReq base auth "people" idStr




