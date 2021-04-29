local Sql   =   require "bot.sqlite"


local sql   =   Sql.create {sql =   {
            init    =   {
                "create table if not exists auto_reply_db (id integer primary key autoincrement"
                .. " ("
                ..  ", content vchar"
                ..  ", nickname vchar"
                ..  ", len_min  integer"
                ..  ", len_max  integer"
                ..  ", at timestamp"
                ..  ", group_title    vchar"
                ..  ", unique (content, nickname)"
                ..");"
            ,   "create table if not exists auto_reply_group  (id integer primary key autoincrement"
                ..  " ("
                ..  ", title vchar"
                ..  ", nickname vchar"
                ..  ", count integer"
                ..  ", at timestamp"
                ..  ", unique (nickname, title)"
                ..  ");"
            ,   "create index if not exists i_a_r_g_n_c_t on auto_reply_group (title, nickname);"
            ,   "create index if not exists ear_db  on auto_reply_db (group_title, nickname);"
        }
        ,   i_group =   {
                template    =   "insert into auto_reply_group (title, nickname, count, at) values('#{title}', '#{nickname}', 1, '#{at}');"
            ,   type        =   "w"
        }
        ,   i_reply =   {
                template    =   "insert into auto_reply_db (content, nickname, len_min, len_max, group_title, at) values('#{content}', '#{nickname}', #{len_min}, #{len_max}, #{group_title}, '#{at}');"
            ,   type        =   "w"
        }
        ,   query   =   {
                template    =   "select * from auto_reply_db where group_title = '#{title}';"
            ,   type        =   "r"
        }
        ,   list    =   {
                template    =   "select * from auto_reply_db;"
            ,   type        =   "r"
        }
    }
}
