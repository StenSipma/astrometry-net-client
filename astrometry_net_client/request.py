import json

import requests

from astrometry_net_client.exceptions import NoSessionError, InvalidSessionError, InvalidRequest

class Request(object):
    """
    Class to make requests to the Astrometry.net API. Intended use mainly for 
    extending / internal class usage.

    Requests are made using the requests library, and is capable of making GET
    and POST requests (controlled by the method argument in the constructor).

    Typical usage (makes a GET request):
     >>> r = Request('some-url')
     >>> response = r.make()

    The constructor prepares the request, but does not yet make it. To send /
    make the request use the method: `r.make()`.
    
    For a POST request:
     >>> r = Request('some-url', method='post', data=data, settings=settings)
     >>> response = r.make()

    where data and settings are both combined and wrapped into the 
    'request-json' form, but are split to allow for some general settings.

    It is valid to omit specifying a url, if the subclass already has its own
    url attribute.

    An alternative for not using the "method='post'" is to use the PostRequest 
    class

    The internal _make_request() method can be used to extend the functionality
    of requests (e.g. AuthorizedRequest: by making sure the user is logged in). 
    
    Additional arguments specied in the constructor (which are not directly 
    used in this class or any subclass) will be stored and passed to the 
    request call.
    """
    _method_dict = {'post': requests.post, 'get': requests.get}

    def __init__(self, url=None, method='get', data=None, settings=None, **kwargs):
        self.data = {} if data is None else data.copy()
        self.settings = {} if settings is None else settings.copy()
        self.arguments = kwargs
        if url is not None:
            self.url = url
        self.method = self._method_dict[method.lower()]
        self.response = None

    def _make_request(self):
        payload = {'request-json': json.dumps({**self.data, **self.settings})}
        response = self.method(self.url, data=payload, **self.arguments)
        print('Response:', response.text)
        response = response.json()
        self.response = response

        # TODO add complete response checking
        if response.get('status', '') == 'error':
            err_msg = response['errormessage']
            if err_msg == 'no "session" in JSON.':
                # No session argument provided
                raise NoSessionError(err_msg)
            if err_msg.startswith('no session with key'):
                # Invalid / Expired session key provided
                raise InvalidSessionError(err_msg)

            # fallback exception for a general error
            raise InvalidRequest(err_msg)

        return self.response

    def make(self):
        """
        Send the actual request to the API.
        returns the response

        This method is mainly for convenience, as to avoid the user unfriendly
        _make_request() method.
        """
        return self._make_request()


class PostRequest(Request):
    """
    Makes a POST request instead of the default GET request. It can be used
    as a mixin class, alongside other 

    Essentially replaces:
     >>> r = Request(url, method='post', arguments...)

    With
     >>> r = PostRequest(url, arguments...)

    For further usage see the Request class
    """
    def __init__(self, *args, method='post', **kwargs):
        """
        Changes the default value for the method parameter. This can still be
        overridden by the user.

        See Request for complete info on the constructor.
        """
        super().__init__(*args, method=method, **kwargs)


class AuthorizedRequest(Request):
    """
    Wraps the normal Request around an authentication layout, ensuring the
    user is logged in and the session key is send alongside the request.

    The separate login request (if needed) is only send just before the 
    original request is made, (e.g. when calling make / _make_request).
    """
    def __init__(self, session, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.session = session

    def _make_request(self):
        self.session.login()
        self.data['session'] = self.session.key
        try:
            return super()._make_request()
        except InvalidSessionError:
            print('Session expired, loggin in again')
            self.session.login(force=True)
            # update the session key for the request as well
            self.data['session'] = self.session.key

        return super()._make_request()
