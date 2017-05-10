class CommentsController < ApplicationController
  before_action :set_comment, only: [:destroy]

  # POST /comments
  def create
    @comment = Comment.new(comment_params)
    @comment.user = current_user

    if @comment.save
      @comment.notify :users
      redirect_to @comment.article, notice: 'Comment was successfully created.'
    else
      redirect_to @comment.article
    end
  end

  # DELETE /comments/1
  def destroy
    article = @comment.article
    @comment.destroy
    redirect_to article, notice: 'Comment was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_comment
      @comment = Comment.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def comment_params
      params.require(:comment).permit(:article_id, :body)
    end
end
