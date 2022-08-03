require 'sinatra'
require 'active_record'
require 'digest/sha2'

set :environment, :production

set :sessions,
  expire_after: 7200,
  secret: 'abcdefghij0123456789'

ActiveRecord::Base.configurations = YAML.load_file('database.yml')
ActiveRecord::Base.establish_connection :development

class BBSdata < ActiveRecord::Base
  self.table_name = 'bbsdata'
end

class Account < ActiveRecord::Base
  self.table_name = 'account'
end

get '/' do
  redirect '/login'
end

get '/login' do
  erb :login
end

post '/auth' do
  user = params[:uname]
  pass = params[:pass]

  r = checkLogin(user, pass)

  if r == 1
    session[:username] = user
    redirect '/contents'
  end

  redirect '/loginfailure'
end

get '/logout' do
  session.clear
  erb :logout
end

get '/loginfailure' do
  session.clear
  erb :loginfailure
end

get 'badrequest' do
  session.clear
  erb :badrequest
end

get '/contents' do
  @u = session[:username]
  if @u == nil
    redirect '/badrequest'
  end

  @t = ""

  a = BBSdata.all
  if a.count == 0
    @t = "<tr><td>No entries in this BBS.</td></tr>"
  else
    a.each do |b|
      @t = @t + "<tr>"
      @t = @t + "<td>#{b.id}</td>"
    c = Account.find(b.userid)
      @t = @t + "<td><img src=\"#{c.iconfile}\" width=64 height=64></td>"
      @t = @t + "<td>#{b.userid}</td>"
      @t = @t + "<td>#{Time.at(b.writedate)}</td>"
      if b.userid == @u
        @t = @t + "<td><form action=\"/delete\" method=\"post\">"
        @t = @t + "<input type=\"text\" value=\"#{b.id}\" name=\"id\" hidden>"
        @t = @t + "<input type=\"hidden\" name=\"_method\" value=\"delete\">"
        @t = @t + "<input type=\"submit\" value=\"Delete\"></form></td>"
      else
        @t = @t + "<td></td>"
      end
      @t = @t + "</tr>"
      if b.imgfile != ""
        @t = @t + "<tr><td colspan=\"4\">#{b.entry}<br><a href=\"#{b.imgfile}\"><img src=\"#{b.imgfile}\" width=400px></a></td></tr>\n"
      else
        @t = @t + "<tr><td colspan=\"4\">#{b.entry}</td></tr>\n"
      end
    end
  end

  erb :contents
end

post '/new' do
  maxid = 0
  a = BBSdata.all # すべての書き込みの中から
  a.each do |b| # idの最大値を調べる
    if b.id > maxid
      maxid = b.id
    end
  end

  s = BBSdata.new
  s.id = maxid + 1 # 既存の書き込みの最大のid+1を新しいidに使う
  s.userid = session[:username]
  s.entry = params[:entry]
  s.writedate = Time.now.to_i

  p = params[:file]
  if p != nil
    save_path = "./public/#{p[:filename]}"
    File.open(save_path, 'wb') do |f|
      g = p[:tempfile]
      f.write g.read
    end
    s.imgfile = "/#{p[:filename]}"
  else
    s.imgfile = ""
  end
  s.save
  redirect '/contents'
end

delete '/delete' do
  s = BBSdata.find(params[:id]) # 当該IDのレコードを探す

  f = s.imgfile # 書き込みの画像ファイルを削除
  if f != ""
    File.delete("./public/#{f}")
  end

  s.destroy # 見つかったら削除する
  redirect '/contents' # 削除した状態を表示し直す
end

def checkLogin(trial_username, trial_password)
  r = 0 # login failure

  begin
    a = Account.find(trial_username)
    db_username = a.id
    db_salt = a.salt
    db_hashed = a.hashed
    trial_hashed = Digest::SHA256.hexdigest(trial_password + db_salt)

    if trial_hashed == db_hashed
      r = 1 # login success
    end
  rescue => e
    r = 2 # unknown user
  end

  return(r)
end
