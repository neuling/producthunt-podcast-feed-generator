require "sugar"

ProducthuntAPI = require "./lib/producthunt_api"
fs             = require "fs"
moment         = require "moment"
winston        = require "winston"
sanitizer      = require "sanitizer"
RSS            = require "rss"

NODE_ENV = process.env.NODE_ENV || "development"

logger = new (winston.Logger)

if NODE_ENV == "development"
  logger.add(winston.transports.Console, prettyPrint: true)
else
  logger.add(winston.transports.File, prettyPrint: true, filename: "log/#{NODE_ENV}.log")

ph = new ProducthuntAPI
  accessToken: "49c3adc71ab80262b15b4208036f9f6f0d7bcc9b3a494fdfb7dbc80fece21cdb"
  debug: NODE_ENV == "development"
  
generateXML = (posts) ->
  feedOptions = 
    title: "Product Hunt Podcasts β"
    description: "All Product Hunt podcast β submissions wrapped in one podcast updated hourly"
    feed_url: "http://phpmp.lab.moritz.pro/feed.xml"
    site_url: "https://www.producthunt.com/podcasts"
    language: "en"
    ttl: 15
    custom_namespaces:
      itunes: "http://www.itunes.com/dtds/podcast-1.0.dtd"
      
    custom_elements: [
      { "itunes:explicit": "clean" }
      { "itunes:summary": "All Product Hunt podcast submissions wrapped in one podcast. Updated hourly!" }
      { "itunes:category": [
        _attr: 
          text: "Technology"
      ]}
    ]
     
  feed = new RSS feedOptions
    
  for post in posts
    
    continue unless post.thumbnail.metadata.url
    
    summary = "<p>▲ #{post.votes_count} | <a href='#{post.discussion_url}'>#{post.tagline}</a></p>"
    
    if post.comments.length > 0
      summary += "<p>Comments</p>"
      
      for comment in post.comments
        body = sanitizer.sanitize(comment.body)
        body = body.replace /(?:\r\n|\r|\n)/g, "<br>"
        summary += "<p><a href='https://producthunt.com/@#{comment.user.username}'>#{comment.user.name}</a>: #{body}</p>"
    
    itemOptions =
      title: " | #{post.name}"
      description: post.tagline
      author: post.makers?.map((m) -> m.name)?.join(", ") || "Unknown"
      guid: post.thumbnail.metadata.url.replace("https", "http")
      url: post.discussion_url
      date: post.created_at
      enclosure:
        url: post.thumbnail.metadata.url.replace("https", "http")
        type: "audio/mpeg"
      
      custom_elements: [
        { "itunes:author": post.makers?.map((m) -> m.name)?.join(", ") || "Unknown" }
        { "itunes:subtitle": post.tagline }
        { "itunes:summary": summary }
        { "itunes:image": { _attr: { href: post.thumbnail.image_url.replace("https", "http") } } }
      ]
    
    feed.item itemOptions
  
  fs.writeFile "feed.xml", feed.xml(indent: true), "utf8"
  
ph.podcasts params: { days_ago: 0 }, (posts1) ->
  ph.podcasts params: { days_ago: 1 }, (posts2) ->
    ph.podcasts params: { days_ago: 2 }, (posts3) ->
      
      posts = posts1.add(posts2).add(posts3)
      
      flatComments = (comments, allComments = []) ->
        allComments.add comments
        for comment in comments
          flatComments(comment.child_comments, allComments) if comment.child_comments && comment.child_comments.length > 0
        allComments
  
      fetchComments = (posts, callback, postsWidthComments = []) ->
        if post = posts.shift()
    
          if post.comments_count > 0
            ph.post_comments post.id, (comments) ->
              post.comments = flatComments(comments)
              postsWidthComments.push post
              fetchComments posts, callback, postsWidthComments
          else
            post.comments = []
            postsWidthComments.push post
            fetchComments posts, callback, postsWidthComments
      
        else
          callback postsWidthComments
  
      fetchComments posts, generateXML
  
  
  
  
  
  
  
  
  