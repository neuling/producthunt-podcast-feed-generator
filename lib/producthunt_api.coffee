require "sugar"
needle = require "needle"

class ProducthuntAPI
  defaults =
    host: "https://api.producthunt.com"
    accessToken: null
    onRequest: null
    onRequestError: null
    maxRequestsPerSecond: 1
    debug: false
    accessTokenIndex: 0
  
  constructor: (options = {}) ->
    options = Object.merge defaults, options, true
    
    accessTokens = ->
      options.accessToken.split ","
      
    nextAccessToken = ->
      options.accessTokenIndex = (options.accessTokenIndex + 1) % accessTokens().length
    
    currentAccessToken = ->
      accessTokens()[options.accessTokenIndex]
    
    resourceNameFromPath = (path) ->
      path.split("/").remove((p) -> "#{Number(p)}" == p || p == "all").last()
    
    get = (path, params = {}, cb = ->) ->
      start = new Date()
      needle.request "GET", "#{options.host}/v1/#{path}", params, headers: { "Authorization": "Bearer #{currentAccessToken()}" }, (err, body, result) ->
        requestTimeInMs = (new Date()) - start
        wait = [(1000 / accessTokens().length) - requestTimeInMs, 0].max()
        nextAccessToken() if body && body.headers && Number(body.headers["x-rate-limit-remaining"]) <= 1
        setTimeout (-> cb(err, body, result)), wait
        
    request = (path, args = {}, cb = ->) ->
      args         = Object.merge { params: {}, all: false, results: [] }, args
      resourceName = resourceNameFromPath(path)
      
      params = Object.merge args.params,
        newer: args.params.newer ? 0
        per_page: args.params.per_page ? 50
        order: "desc"

      get path, params, (err, body, result) ->
        onSuccess = (err, body, result, cb) ->
          result = result[resourceName] ? result[resourceName.singularize()]

          if Object.isArray(result) && args.all
            if result.isEmpty() || result.length < Number(params.per_page)
              cb args.results.add(result)
            else
              params.newer = result.map("id").max()
              args.results = args.results.add(result)
              request path, args, cb
          else
            cb(result)
      
        if body && result && !err && !result.error
          options.onRequest path, params, err, body, result if typeof(options.onRequest) == "function"
          return onSuccess(err, body, result, cb)
        else
          options.onRequestError path, params, err, body, result if typeof(options.onRequestError) == "function"
          return cb([])
  
    @posts = (args...) ->
      args = if args.length == 2 then args else [{}, args[0]]
      request.apply(this, ["posts"].add(args))
      
    @podcasts = (args...) ->
      args = if args.length == 2 then args else [{}, args[0]]
      request.apply(this, ["categories/podcasts/posts"].add(args))
      
    @all_posts = (args...) ->
      args = if args.length == 2 then args else [{}, args[0]]
      request.apply(this, ["posts/all"].add(args))
      
    @post_votes = (id, args...) ->
      args = if args.length == 2 then args else [{}, args[0]]
      request.apply(this, ["posts/#{id}/votes"].add(args))
    
    @post_comments = (id, args...) ->
      args = if args.length == 2 then args else [{}, args[0]]
      request.apply(this, ["posts/#{id}/comments"].add(args))
      
      
module.exports = ProducthuntAPI