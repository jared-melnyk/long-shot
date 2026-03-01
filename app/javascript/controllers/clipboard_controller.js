import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["feedback"]

  copy(event) {
    const url = this.element.dataset.inviteUrl || this.urlValue
    if (!url) return
    navigator.clipboard.writeText(url).then(() => {
      if (this.hasFeedbackTarget) {
        this.feedbackTarget.classList.remove("hidden")
        setTimeout(() => this.feedbackTarget.classList.add("hidden"), 2000)
      }
    })
  }
}
